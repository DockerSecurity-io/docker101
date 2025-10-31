-- Cross-format support for indices (LaTeX, HTML, EPUB, ...)
--
-- Syntax is based on LaTeX: https://en.wikibooks.org/wiki/LaTeX/Indexing
-- Creating entries: \index{key}
-- Creating the index: \printindex

-- ########## Shared data ##########

local indexEntryCounter = 0
local indexEntries = {}

-- ########## Collecting index entries ##########

function RawInlineIndexHtml(el)
  if el.format == "tex" then
    local indexEntry = extractIndexEntry(el.text)
    if indexEntry ~= nil then
      return createIndexAnchor(indexEntry)
    end
  end
  return nil -- no change
end

function RawBlockIndexHtml(el)
  if el.format == "tex" then
    local indexEntry = extractIndexEntry(el.text)
    if indexEntry ~= nil then
      return pandoc.Plain({createIndexAnchor(indexEntry)})
    end
  end
  return nil -- no change
end

function extractIndexEntry(elementText)
  local indexArg = string.match(elementText, "\\index{([^}]*)}")
  if indexArg ~= nil then
    local indexEntry = {
      id = "index-entry-" .. tostring(indexEntryCounter)
    }
    indexEntryCounter = indexEntryCounter + 1

    local key, text = string.match(indexArg, "^([^@]+)@([^@]+)$")
    if key ~= nil then
      -- Example: indexArg == "assert@`assert` (module)"
      indexEntry.key = key
      local document = pandoc.read(text, "markdown")
      indexEntry.markup = document.blocks[1].content
    else
      -- Example: indexArg == "bundler"
      indexEntry.key = indexArg
      indexEntry.markup = {pandoc.Str(indexArg)} -- list of inlines
    end
    if string.match(indexEntry.key, "^[A-Za-z]") then
      indexEntry.sortKey = indexEntry.key
    else
      -- Alas, "&" comes before "A", while "|" comes after "Z"
      -- Fix by prepending a space
      indexEntry.sortKey = " " .. indexEntry.key
    end
    table.insert(indexEntries, indexEntry)
    return indexEntry
  else
    return nil
  end
end

function createIndexAnchor(indexEntry)
  return pandoc.RawInline("html", "<a id=\"" .. indexEntry.id .. "\" class=\"index-entry\"></a>")
end

-- ########## Generating the index ##########

function sortEntries(e1, e2)
  local key1Lower = string.lower(e1.sortKey)
  local key2Lower = string.lower(e2.sortKey)
  if key1Lower == key2Lower then
    -- "FOO" must always come before "foo"
    return e1.sortKey < e2.sortKey
  end
  return key1Lower < key2Lower
end

function RawBlockPrintIndexHtml(el)
  if el.format == "tex" then
    if el.text == "\\printindex" then
      table.sort(indexEntries, sortEntries)
      local prevEntryTitle = ""
      local result = {}
      local bulletListItems = {}
      for _,entry in ipairs(indexEntries) do
        local curEntryTitle = extractEntryTitle(entry.key)
        if curEntryTitle ~= prevEntryTitle then
          if countEntries(bulletListItems) > 0 then
            table.insert(result, pandoc.BulletList(bulletListItems))
            bulletListItems = {}
          end
          table.insert(result, pandoc.Para({pandoc.Str(curEntryTitle)}))
          prevEntryTitle = curEntryTitle
        end
        local link = pandoc.Link(entry.markup, "#" .. entry.id)
        table.insert(bulletListItems, {pandoc.Plain(link)})
      end
      if countEntries(bulletListItems) > 0 then
        table.insert(result, pandoc.BulletList(bulletListItems))
        bulletListItems = {}
      end
      return result
    end
  end
  return nil -- no change
end

function extractEntryTitle(str)
  local l = string.upper(string.sub(str, 0, 1))
  if string.match(l, "^[A-Z]$") then
    return l
  else
    return "Symbol"
  end
end

-- ########## LaTeX ##########

function RawInlineIndexLatex(el)
  if el.format == "tex" then
    local rawText = createRawText(el.text)
    if rawText ~= nil then
      return pandoc.RawInline("tex", rawText)
    end
  end
  return nil -- no change
end

function RawBlockIndexLatex(el)
  if el.format == "tex" then
    local rawText = createRawText(el.text)
    if rawText ~= nil then
      return pandoc.RawBlock("tex", rawText)
    end
  end
  return nil -- no change
end

function createRawText(elementText)
  local indexArg = string.match(elementText, "\\index{([^}]*)}")
  if indexArg ~= nil then
    local key, text = string.match(indexArg, "^([^@]+)@([^@]+)$")
    if key ~= nil then
      key = string.gsub(key, "([|!])", "\"%1")
      text = string.gsub(text, "`([^`]+)`", "\\verb§%1§")
      text = string.gsub(text, "([|!])", "\"%1")
      return "\\index{" .. key .. "@" .. text .. "}"
    else
      return "\\index{" .. indexArg .. "}" -- keep simple entries
    end
  end
  return nil
end

-- ########## Utilities ##########

function printTable(tbl)
  for k,v in pairs(tbl) do
    print('KEY', k, 'VALUE', v)
  end
end

function countEntries(tbl)
  local count = 0
  for _ in pairs(tbl) do
    count = count + 1
  end
  return count
end

function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- ########## Setup ##########

if FORMAT == "latex" then
  return {
    {RawInline=RawInlineIndexLatex,RawBlock=RawBlockIndexLatex},
  }
else
  return {
    {RawInline=RawInlineIndexHtml,RawBlock=RawBlockIndexHtml},
    {RawBlock=RawBlockPrintIndexHtml}
  }
end
