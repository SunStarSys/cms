# SunStar Systems CMS (Build Toolchain)

## Obsoleted Python-Markdown-based build system

### This includes mdx_elementid.py support.

## New build system is based on node.js and Editor.md: markdown.js!

### npm prerequisites: jquery, navigator, jsdom.

### markdown.js ENV VARS: NODE_PATH, EDITOR_MD, and MARKDOWN_SOCKET.

### Enjoy: no more deltas between online editor previews and build system markdown rendering

# HOWTO

1. Create a source tree with the following layout:

   - trunk/
       - content/
       - cgi-bin/ (optional)
       - lib/
           - path.pm
           - view.pm
       - templates/

    See <https://vcs.sunstarsys.com/repos/svn/public/site> for a live example.

2. Launch the markdown.js daemon in the background.

3. Run build_site.pl --source-base /path/to/sources/trunk --target-base /wherever/you/want

# Python 3.8 Port Plan

## Reuse /lib:

   - lib/
     - SunStarSys/
       - View.py (volunteers needed!)
       - Util.py (I will handle this)

   - build_file.py (volunteers?)
   - build_site.py (volunteers?)
