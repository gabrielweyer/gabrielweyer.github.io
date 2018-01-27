# gabrielweyer.github.io

Source for my [blog][blog].

| CI | Status |
| --- | --- |
| [CircleCI][circle-ci] | [![Build Status][circle-ci-shield]][circle-ci] |

## Development

```posh
docker run --rm --volume="$($PWD):/srv/jekyll" -p 4000:4000 -it jekyll/jekyll:3.6.2 jekyll serve
```

You can serve your [drafts][working-with-drafts] by adding the `--drafts` switch at the end of the command.

## Release

- Always work in the `develop` branch
- Once you're done: `git push origin develop`

[blog]: https://gabrielweyer.github.io/
[circle-ci]: https://circleci.com/gh/gabrielweyer/gabrielweyer.github.io
[circle-ci-shield]: https://circleci.com/gh/gabrielweyer/gabrielweyer.github.io/tree/develop.svg?style=shield
[working-with-drafts]: https://jekyllrb.com/docs/drafts/
