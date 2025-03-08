Changelog
=========

We are operating with `semantic versioning <https://semver.org>`_.

..
    Please try to update this file in the commits that make the changes.

    To make merging/rebasing easier, we don't manually break lines in here
    when they are too long, so any particular change is just one line.

    To make tracking easier, please add either ``closes #123`` or ``fixes #123``
    to the first line of the commit message. There are more syntaxes at:
    <https://blog.github.com/2013-01-22-closing-issues-via-commit-messages/>.

    Note that they these tags will not actually close the issue/PR until they
    are merged into the "default" branch.


v15.0.0 (Unreleased)
--------------------

Major:

- Turn ``av.ValueError`` into ``av.ArgumentError``. The latter is now not a subclass of ``ValueError``. This change better reflects how users should think about this exception.

Features:

- Add support for Python free-threading builds.

