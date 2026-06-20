set shell := ["nu", "-c"]

default:
    @just --list

build:
    flix build

add task:
    flix run -- add "{{task}}"

read:
    flix run -- read | from json

delete title:
    flix run -- delete "{{title}}"
