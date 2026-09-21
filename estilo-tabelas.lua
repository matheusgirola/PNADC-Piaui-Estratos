-- Aplica o estilo de parágrafo "Tabela Texto" (definido em
-- custom-reference-notatecnica.docx) ao conteúdo de toda célula de tabela.
-- Necessário porque o pandoc usa o estilo "Compact" nas células, que herda
-- a fonte do Normal e sobrepõe a fonte do estilo de tabela "Table".
local function estilizar(linhas)
  for _, linha in ipairs(linhas) do
    for _, celula in ipairs(linha.cells) do
      -- Plain em célula vira "Compact" à força no writer docx; Para respeita
      -- o custom-style da Div.
      local blocos = celula.contents:walk({ Plain = function(p) return pandoc.Para(p.content) end })
      celula.contents = { pandoc.Div(blocos, { ["custom-style"] = "Tabela Texto" }) }
    end
  end
end

function Table(tbl)
  estilizar(tbl.head.rows)
  for _, corpo in ipairs(tbl.bodies) do
    estilizar(corpo.head)
    estilizar(corpo.body)
  end
  estilizar(tbl.foot.rows)
  return tbl
end
