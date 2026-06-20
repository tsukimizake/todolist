set shell := ["nu", "-c"]

default:
    @just --list

build:
    flix build

add task dueDate="today":
    let dueDate = ("{{dueDate}}" | date from-human | format date "%Y-%m-%d"); flix run -- add "{{task}}" $dueDate

list:
    flix run -- list | from json | transpose title item | flatten item | sort-by dueDate

delete:
    let title = (flix run -- list | from json | columns | str join (char nl) | fzf | str trim); flix run -- delete $title

touch:
    let title = (flix run -- list | from json | columns | str join (char nl) | fzf | str trim); flix run -- touch $title

complete:
    let title = (flix run -- list | from json | columns | str join (char nl) | fzf | str trim); flix run -- complete $title
