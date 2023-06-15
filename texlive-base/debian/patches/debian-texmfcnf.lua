Adjust the texmfcnf.lua file to realities in Debian
---
--- texlive-base-2022.20230613.orig/texmf-dist/web2c/texmfcnf.lua
+++ texlive-base-2022.20230613/texmf-dist/web2c/texmfcnf.lua
@@ -11,6 +11,7 @@
     comment = "ConTeXt MkIV and LMTX configuration file",
     author  = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
     target  = "texlive",
+    -- adaption by Preining Norbert / Hilmar Preuße for the Debian system
 
     content = {
 
@@ -52,7 +53,7 @@
 
             TEXMFVAR        = "home:" .. hiddentexlivepath .. "/texmf-var",
             TEXMFCONFIG     = "home:" .. hiddentexlivepath .. "/texmf-config",
-            TEXMFSYSVAR     = "selfautoparent:texmf-var",
+            TEXMFSYSVAR     = "/var/lib/texmf",
             TEXMFCACHE      = "$TEXMFSYSVAR;$TEXMFVAR",
 
             -- I don't like this texmf under home and texmf-home would make more sense. One never knows
@@ -62,7 +63,7 @@
             -- By using prefixes we don't get expanded paths in the cache __path__ entry. This makes the
             -- tex root relocatable.
 
-            TEXMFOS         = "selfautodir:",
+            -- TEXMFOS         = "selfautodir:",
 
             -- standalone:
 
@@ -73,14 +74,15 @@
 
             -- texlive:
 
-            TEXMFDIST       = "selfautoparent:texmf-dist",
-            TEXMFSYSCONFIG  = "selfautoparent:texmf-config",
+            TEXMFDIST       = "/usr/share/texlive/texmf-dist",
+	    TEXMFDEBIAN     = "/usr/share/texmf",
+            TEXMFSYSCONFIG  = "/etc/texmf",
 
             -- The texmf-local path is only used for (maybe) some additional configuration file.
 
-            TEXMFLOCAL      = "selfautoparent:texmf-local",
-            TEXMFFONTS      = "selfautoparent:texmf-fonts",
-            TEXMFPROJECT    = "selfautoparent:texmf-project",
+            TEXMFLOCAL      = "/usr/local/share/texmf",
+            -- TEXMFFONTS      = "selfautoparent:texmf-fonts",
+            -- TEXMFPROJECT    = "selfautoparent:texmf-project",
 
             TEXMFHOME       = "home:texmf",
          -- TEXMFHOME       = os.name == "macosx" and "home:Library/texmf" or "home:texmf",
@@ -94,7 +96,7 @@
 
             -- texlive:
 
-            TEXMF           = "{$TEXMFCONFIG,$TEXMFHOME,!!$TEXMFSYSCONFIG,!!$TEXMFSYSVAR,!!$TEXMFPROJECT,!!$TEXMFFONTS,!!$TEXMFLOCAL,!!$TEXMFDIST}",
+            TEXMF           = "{$TEXMFCONFIG,$TEXMFHOME,!!$TEXMFSYSCONFIG,!!$TEXMFSYSVAR,!!$TEXMFLOCAL,!!$TEXMFDEBIAN,!!$TEXMFDIST}",
 
             TEXFONTMAPS     = ".;$TEXMF/fonts/data//;$TEXMF/fonts/map/{pdftex,dvips}//",
             ENCFONTS        = ".;$TEXMF/fonts/data//;$TEXMF/fonts/enc/{dvips,pdftex}//",
@@ -228,7 +230,7 @@
             -- In an edit cycle it can be handy to launch an editor. The
             -- preferred one can be set here.
 
-         -- ["pdfview.method"]           = "sumatra",
+         -- ["pdfview.method"]           = "see",
 
          -- ["system.engine"]            = "luajittex",
          -- ["fonts.usesystemfonts"]     = false,
