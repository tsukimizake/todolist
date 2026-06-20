use Util.Json.FromJson.decodeAtKey;
use Util.Json.JsonPath
use Util.Json.JsonError.DecodeErrorKind
use Util.Json.JsonError;
use Util.Json;
use Sys.Env
use Sys.Env.getUserHomeDirectory
use Sys.Process
import java.time.LocalDate

def todoDir(): String \ {Env, Abort} =
    Option.getOrAbort(getUserHomeDirectory()) ++ "/.todolist"

def todoFilePath(): String \ {Env, Abort} =
    todoDir() ++ "/todo.json"

def runGit(cwd: String, args: List[String]): Unit \ {Process, Abort} =
    let ph = Sys.Process.execWithCwd("git", args, Some(cwd)) |> Result.getOrAbort;
    let _ = Sys.Process.waitFor(ph) |> Result.getOrAbort;
    ()

def ensureRepo(): Unit \ {Env, Abort, IO, Process} =
    let dir = todoDir();
    let _ = Fs.FsLayer.mkDirs(dir) |> Result.getOrAbort;
    let gitDir = dir ++ "/.git";
    if (Fs.FsLayer.exists(gitDir) |> Result.getOrAbort)
        ()
    else
        runGit(dir, "init" :: Nil);
    let path = todoFilePath();
    if (Fs.FsLayer.exists(path) |> Result.getOrAbort)
        ()
    else
        let _ = Fs.FsLayer.write({str = "{}\n"}, path) |> Result.getOrAbort;
        ()

def commit(msg: String): Unit \ {Env, Abort, Process} =
    let dir = todoDir();
    runGit(dir, "add" :: "." :: Nil);
    runGit(dir, "commit" :: "-m" :: msg :: Nil)

enum TodoStatus {
    case TODO,
    case IN_PROGRESS,
    case DONE
}

instance Json.FromJson[TodoStatus] {
    pub def fromJson(j: Json): Result[JsonError, TodoStatus] =
        match j {
            case Json.JString("TODO") => Ok(TodoStatus.TODO)
            case Json.JString("IN_PROGRESS") => Ok(TodoStatus.IN_PROGRESS)
            case Json.JString("DONE") => Ok(TodoStatus.DONE)
            case _ => Err(JsonError.Decode(JsonPath.empty(), DecodeErrorKind.TypeMismatch("")))
        }
}

instance Json.ToJson[TodoStatus] {
    pub def toJson(x: TodoStatus): Json =
        match x {
            case TodoStatus.TODO => Json.JString("TODO")
            case TodoStatus.IN_PROGRESS => Json.JString("IN_PROGRESS")
            case TodoStatus.DONE => Json.JString("DONE")
        }
}

enum TodoBody({dueDate = String, status = TodoStatus})

instance Json.FromJson[TodoBody] {
    pub def fromJson(j: Json): Result[JsonError, TodoBody] =
        forM (
            dueDate <- decodeAtKey("dueDate", j);
            status <- decodeAtKey("status", j)
        ) yield TodoBody.TodoBody({dueDate = dueDate, status = status})
}

instance Json.ToJson[TodoBody] {
    pub def toJson(x: TodoBody): Json =
        let TodoBody.TodoBody(r) = x;
        Json.JObject(Map#{
            "dueDate" => Json.ToJson.toJson(r#dueDate),
            "status"  => Json.ToJson.toJson(r#status)
        })
}

def loadTodos(path: String): Map[String, TodoBody] \ {IO, Abort} =
    let content = Fs.FsLayer.read(path) |> Result.getOrAbort;
    if (String.isEmpty(String.trim(content)))
        Map.empty()
    else
        (Json.decode(content): Result[JsonError, Map[String, TodoBody]]) |> Result.getOrAbort

def saveTodos(path: String, todos: Map[String, TodoBody]): Unit \ {IO, Abort} =
    let json = Json.toPrettyString(2, Json.ToJson.toJson(todos));
    let _ = Fs.FsLayer.write({str = json ++ "\n"}, path) |> Result.getOrAbort;
    ()

def addItem(path: String, title: String, dueDate: String): Unit \ {IO, Env, Abort, Process} =
    let todos = loadTodos(path);
    if (Map.memberOf(title, todos))
        Abort.abortWithTrace("Title already exists: ${title}")
    else
        let body = TodoBody.TodoBody({dueDate = dueDate, status = TodoStatus.TODO});
        saveTodos(path, Map.insert(title, body, todos));
        commit("add: " ++ title);
        println("Added: " ++ title ++ " (" ++ dueDate ++ ")")

def deleteItem(path: String, title: String): Unit \ {IO, Env, Abort, Process} =
    let todos = loadTodos(path);
    if (not Map.memberOf(title, todos))
        Abort.abortWithTrace("No such title: ${title}")
    else
        saveTodos(path, Map.remove(title, todos));
        commit("delete: " ++ title);
        println("Deleted: " ++ title)

def updateItem(path: String, title: String, transform: TodoBody -> TodoBody): Unit \ {IO, Env, Abort, Process} =
    let todos = loadTodos(path);
    match Map.get(title, todos) {
        case None => Abort.abortWithTrace("No such title: ${title}")
        case Some(body) =>
            saveTodos(path, Map.insert(title, transform(body), todos));
            commit("update: " ++ title);
            println("Updated: " ++ title)
    }

def main(): Unit \ {IO, Env, Abort, Process} =
    let args = Sys.Env.getArgs();
    ensureRepo();
    let path = todoFilePath();
    match args {
        case "add" :: title :: date :: Nil =>
            let dueDate = match date {
                case "" => LocalDate.now().toString()
                case d  => d
            };
            addItem(path, title, dueDate)
        case "read" :: Nil =>
            let content = Fs.FsLayer.read(path) |> Result.getOrAbort;
            println(String.trim(content))
        case "delete" :: title :: Nil =>
            deleteItem(path, title)
        case "touch" :: title :: Nil =>
            let today = LocalDate.now().toString();
            updateItem(path, title, body ->
                let TodoBody.TodoBody(r) = body;
                TodoBody.TodoBody({dueDate = today | r}))
        case "complete" :: title :: Nil =>
            updateItem(path, title, body ->
                let TodoBody.TodoBody(r) = body;
                TodoBody.TodoBody({status = TodoStatus.DONE | r}))
        case _ =>
            println("Usage: add <title> <dueDate> | read | delete <title> | touch <title> | complete <title>")
    }
