set shell := ["nu", "-c"]

default:
    @just --list

build:
    flix build

add task dueDate="today":
    let dueDate = ("{{dueDate}}" | date from-human | format date "%Y-%m-%d"); flix run -- add "{{task}}" $dueDate

read:
    flix run -- read | from json | sort-by dueDate

delete title:
    flix run -- delete "{{title}}"
