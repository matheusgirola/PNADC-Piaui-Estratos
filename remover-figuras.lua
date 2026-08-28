function Blocks(blocks)
  local i = 1
  while i <= #blocks do
    -- Se encontrarmos um parágrafo que contém uma imagem
    if blocks[i].t == "Para" and blocks[i].content[1] and blocks[i].content[1].t == "Image" then
      
      -- 1. Remove a Fonte (próximo bloco), se ele existir e começar com "Fonte:"
      if blocks[i+1] and blocks[i+1].t == "Para" then
        local texto_proximo = pandoc.utils.stringify(blocks[i+1])
        if string.match(texto_proximo, "^Fonte:") then
          table.remove(blocks, i+1)
        end
      end
      
      -- 2. Remove a imagem atual
      table.remove(blocks, i)
      
      -- 3. Remove o Título (bloco anterior), se ele começar com "**Figura" ou "**Fig."
      if i > 1 and blocks[i-1] and blocks[i-1].t == "Para" then
        local texto_anterior = pandoc.utils.stringify(blocks[i-1])
        if string.match(texto_anterior, "^Figura") or string.match(texto_anterior, "^%*%*Figura") then
          table.remove(blocks, i-1)
          i = i - 1 -- Ajusta o ponteiro pois removemos um elemento anterior
        end
      end
      
    else
      i = i + 1
    end
  end
  return blocks
end