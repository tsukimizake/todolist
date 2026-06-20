use Util.Json.FromJson.decodeAtKey;
use Util.Json.JsonPath
use Util.Json.JsonError.DecodeErrorKind
use Util.Json.JsonError;
use Util.Json;
use Fs.WriteFile
use Fs.FileExists
use Sys.Env
use Sys.Env.getUserHomeDirectory
use Sys.Process
import java.time.LocalDate

def todoDir(): String \ {Env, Abort} =
    Option.getOrAbort(getUserHomeDirectory()) ++ "/.todolist"

def todoFilePath(): String \ {Env, Abort} =
    todoDir() ++ "/todo.jsonl"

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
        let _ = Fs.FsLayer.write({str = ""}, path) |> Result.getOrAbort;
        ()

def commit(msg: String): Unit \ {Env, Abort, Process} =
    let dir = todoDir();
    runGit(dir, "add" :: "." :: Nil);
    runGit(dir, "commit" :: "-m" :: msg :: Nil)

def addItem(path: String, title: String, dueDate: String): Unit \ {IO, Env, Abort, Process} =
    let newItem =
        TodoItem.TodoItem({title = title, dueDate = dueDate, status = TodoStatus.TODO})
            |> Json.ToJson.toJson
            |> Json.toCompactString;
    let _ = Fs.FsLayer.append({str = newItem ++ "\n"}, path) |> Result.getOrAbort;
    commit("add: " ++ title);
    println("Added: " ++ title ++ " (" ++ dueDate ++ ")")

def getOrCreateFile(path: String): String \ {Abort, FileExists, WriteFile} =
    if (Fs.FileExists.exists(path) |> Result.getOrAbort)
        path
    else
        let _ = Fs.WriteFile.write({str = ""}, path);
        path

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

enum TodoItem({
        title = String,
        dueDate = String,
        status = TodoStatus
})

instance Json.FromJson[TodoItem] {
    pub def fromJson(j: Json): Result[JsonError, TodoItem] =
        forM (
            title <- decodeAtKey("title", j);
            dueDate <- decodeAtKey("dueDate", j);
            status <- decodeAtKey("status", j)
        ) yield TodoItem.TodoItem({title = title, dueDate = dueDate, status = status})
}

instance Json.ToJson[TodoItem] {
    pub def toJson(x: TodoItem): Json =
        let TodoItem.TodoItem(r) = x;
        Json.JObject(Map#{
            "title"   => Json.ToJson.toJson(r#title),
            "dueDate" => Json.ToJson.toJson(r#dueDate),
            "status"  => Json.ToJson.toJson(r#status)
        })
}


def main(): Unit \ {IO, Env, Abort, Process} =
    let args = Sys.Env.getArgs();
    ensureRepo();
    let path = todoFilePath();
    match args {
        case "add" :: title :: rest =>
            let dueDate = match rest {
                case "" :: Nil => LocalDate.now().toString()
                case d :: Nil => d
                case _        => LocalDate.now().toString()
            };
            addItem(path, title, dueDate)
        case "read" :: Nil =>
            let lines = Fs.FsLayer.readLines(path) |> Result.getOrAbort;
            let nonEmpty = List.filter(s -> not String.isEmpty(s), lines);
            println("[" ++ String.intercalate(",", nonEmpty) ++ "]")
        case "delete" :: title :: Nil =>
            let lines = Fs.FsLayer.readLines(path) |> Result.getOrAbort;
            let filtered = List.filter(s -> not String.contains({substr = title}, s), lines);
            let _ = Fs.FsLayer.write({str = String.intercalate("\n", filtered) ++ "\n"}, path) |> Result.getOrAbort;
            commit("delete: " ++ title);
            println("Deleted entries containing: " ++ title)
        case _ =>
            println("Usage: add <title> [dueDate] | read | delete <title>")
    }
