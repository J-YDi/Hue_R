# Colors codes in R
## Find the RGB and HEX codes for all named colors in R and ggplot2 --> colors_codes_in_R
## Same for palette colors --> palettes_codes_in_R
### Sheets are colored according to the... color, for a better visualization
The colour palettes have been chosen to show only 15 colours; if the palette is made up of fewer colours, then all the colours are present. The palettes are taken from the R database and the paletteer, RColorBrewer and wesanderson packages. The paletteer discrete palettes have their own file, not coloured in Excel, because there are too many cells to colour.
you can find the R code for colors codes extraction and Excel cell coloration for more details or adaptation

## Online app
**https://j-ydi.github.io/colors_codes_in_R/** — runs entirely in your browser (Shinylive / webR), nothing to install.

- **Colors**: the colour sheet, a search by name giving the RGB and HEX codes, and a reverse search (type a HEX or `R, G, B` value to get the closest named colours).
- **Palettes**: choose the number of colours (1 to 30), browse the sheet (filters by package and type), search a palette by name to get its RGB and HEX codes, copy them as an R vector, and get the R code that reproduces them. Discrete palettes have a fixed size: when more colours are requested, all of their colours are shown.

Click any row of a sheet to get its codes.

### Structure
- `app/app.R`: the Shiny app (only needs `shiny` and `bslib`)
- `app/data/`: pre-computed colours and palettes
- `data-raw/build_data.R`: rebuilds `app/data/` (needs `paletteer`, `wesanderson` and the palette packages used by `paletteer`). Run it from the repository root, e.g. after updating `paletteer`.
- `.github/workflows/deploy-shinylive.yml`: exports the app with Shinylive and publishes it on GitHub Pages at each push on `main`.

Run locally: `shiny::runApp("app")`.

#### DIAS Jean-Yves
