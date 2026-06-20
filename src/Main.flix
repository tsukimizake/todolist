use Util.Json.JsonPath
use Util.Json.JsonError.DecodeErrorKind
use Util.Json.JsonError.ParseErrorKind
use Util.Json.JsonError;
use Util.Json;
import java.lang.Record
import java.util.Vector
use Fs.WriteFile
use Fs.FileExists
use Sys.Env
use Sys.Env.getUserHomeDirectory

def todoFilePath(): String \ {Env, Abort} =
    Option.getOrAbort(getUserHomeDirectory()) ++ "/.todo.txt"

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

enum TodoItem ({
    title = String,
    dueDate = String,
    status = TodoStatus
})

instance Json.FromJson[TodoItem] {
    pub def fromJson(j: Json): Result[JsonError, TodoItem] = 
        def getAsString(field: Option[Json]): Result[JsonError, String] =
            match field {
                case Some(Json.JString(s)) => Ok(s)
                case _ => Err(JsonError.Parse(1, ParseErrorKind.InvalidUnicode("")))
            };
        match j {
            case Json.JObject(fields) =>
                let title = Map.get("title", fields)|> getAsString ;
                let dueDate = Map.get("dueDate", fields) |> getAsString; 
                let status = Map.get("status", fields) |>getAsString |> fromJson();
                match (title, dueDate, status) {
                    case (Ok(t), Ok(d), Ok(s)) => Ok(TodoItem({title = t, dueDate = d, status = s}))
                    case _ => Err(JsonError.Decode(JsonPath.empty(), DecodeErrorKind.TypeMismatch("")))
                }
            case _ => Err(JsonError.Decode(JsonPath.empty(), DecodeErrorKind.TypeMismatch("")))
        }
                
}

// instance Json.ToJson[TodoItem] {
//
//     pub def toJson(x: t): Json = ???
//
// }


def main(): Unit \ {IO, Env, Abort} =
    let args = Sys.Env.getArgs();
    println(args);
    let p = todoFilePath();
    println(p)
