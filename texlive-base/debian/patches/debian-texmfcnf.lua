Adjust the texmfcnf.lua file to realities in Debian
---
 texmf-dist/web2c/texmfcnf.lua |   27 ++++++++++++---------------
 1 file changed, 12 insertions(+), 15 deletions(-)

--- a/texmf-dist/web2c/texmfcnf.lua
+++ b/texmf-dist/web2c/texmfcnf.lua
@@ -3,17 +3,15 @@
 -- ConTeXt needs a properly expanded TEXMFLOCAL, so here is a
 -- bit of lua code to make that happen
 
-local texmflocal = resolvers.prefixes.selfautoparent();
-texmflocal = string.gsub(texmflocal, "20%d%d$", "texmf-local");
-
 return {
 
     type    = "configuration",
     version = "1.1.0",
-    date    = "2012-05-24",
+    date    = "2012-05-14", -- or so
     time    = "12:12:12",
     comment = "ConTeXt MkIV configuration file",
     author  = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
+    -- adaption by Preining Norbert for the Debian system
 
     content = {
 
@@ -43,8 +41,7 @@ return {
             -- }
 
             -- only used for FONTCONFIG_PATH & TEXMFCACHE in TeX Live
-
-            TEXMFSYSVAR     = "selfautoparent:texmf-var",
+            TEXMFSYSVAR     = "/var/lib/texmf",
             TEXMFVAR        = "home:.texlive2021/texmf-var",
 
             -- We have only one cache path but there can be more. The first writable one
@@ -61,13 +58,13 @@ return {
             -- By using prefixes we don't get expanded paths in the cache __path__
             -- entry. This makes the tex root relocatable.
 
-            TEXMFOS         = "selfautodir:",
-            TEXMFDIST       = "selfautoparent:texmf-dist",
-
-            TEXMFLOCAL      = texmflocal,
-            TEXMFSYSCONFIG  = "selfautoparent:texmf-config",
-            TEXMFFONTS      = "selfautoparent:texmf-fonts",
-            TEXMFPROJECT    = "selfautoparent:texmf-project",
+            -- TEXMFOS         = "selfautodir:",
+            TEXMFDIST       = "/usr/share/texlive/texmf-dist",
+            TEXMFDEBIAN     = "/usr/share/texmf",
+            TEXMFLOCAL      = "/usr/local/share/texmf",
+            TEXMFSYSCONFIG  = "/etc/texmf",
+            -- TEXMFFONTS      = "selfautoparent:texmf-fonts",
+            -- TEXMFPROJECT    = "selfautoparent:texmf-project",
 
             TEXMFHOME       = "home:texmf",
          -- TEXMFHOME       = os.name == "macosx" and "home:Library/texmf" or "home:texmf",
@@ -75,7 +72,7 @@ return {
             -- We need texmfos for a few rare files but as I have a few more bin trees
             -- a hack is needed. Maybe other users also have texmf-platform-new trees.
 
-            TEXMF           = "{$TEXMFCONFIG,$TEXMFHOME,!!$TEXMFSYSCONFIG,!!$TEXMFSYSVAR,!!$TEXMFPROJECT,!!$TEXMFFONTS,!!$TEXMFLOCAL,!!$TEXMFDIST}",
+            TEXMF           = "{$TEXMFCONFIG,$TEXMFHOME,!!$TEXMFSYSCONFIG,!!$TEXMFSYSVAR,!!$TEXMFLOCAL,!!$TEXMFDEBIAN,!!$TEXMFDIST}",
 
             TEXFONTMAPS     = ".;$TEXMF/fonts/data//;$TEXMF/fonts/map/{pdftex,dvips}//",
             ENCFONTS        = ".;$TEXMF/fonts/data//;$TEXMF/fonts/enc/{dvips,pdftex}//",
@@ -174,7 +171,7 @@ return {
             -- In an edit cycle it can be handy to launch an editor. The
             -- preferred one can be set here.
 
-         -- ["pdfview.method"]           = "okular", -- default (often acrobat) xpdf okular
+         -- ["pdfview.method"]           = "see", -- default (often acrobat) xpdf okular
 
         },
 
