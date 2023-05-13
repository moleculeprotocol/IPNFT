library(plotly)

fig <- plot_ly(
  type = "sankey",
  orientation = "h",
  node = list(
    label = c("Alice (ETH)","Bob (ETH)", 
              "Alice (VITA)","Bob (VITA)",
              "Committed ETH","Committed VITA",
              "Alice (Overflow ETH)", "Bob (Overflow ETH)",
              "Fundraise for Project (ETH)", "Fractions for Sale (FAM)",
              "Alice (Vested FAM)", "Bob (Vested FAM)",
              "Alice (Liquid VITA)","Bob (Liquid VITA)",
              "Alice (Vested VITA)","Bob (Vested VITA)"
              ),
    color = c("Purple","Blue","Purple","Blue","Gray","Yellow",
              "Purple","Blue","Black","Black","Purple","Blue",
              "Purple","Blue","Purple","Blue"),
    pad = 15,
    thickness = 20,
    line = list(
      color = "black",
      width = 0.5
    )
  ),
  
  link = list(
    source = c(0,1,2,3,4,4,4,9,9,5,5,5,5),
    target = c(4,4,5,5,6,7,8,10,11,14,15,12,13),
    value =  c(8,4,8,4,1.33,0.67,10,6.67,3.33,6.67,3.33,1.33,0.67)
  )
)
fig %>% layout(
  title = "Basic Sankey Diagram",
  font = list(
    size = 20
  )
)
