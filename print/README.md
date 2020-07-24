# German printed text experiment

### File structure

```
data
├── imgs
│   ├── lines (imgtxtenh lines)
│   │   └── {tr,va,te} (.jpg)
│   ├── lines_h128 (imgtxtenh, height 128 lines)
│   │   └── {tr,va,te} (.jpg)
│   └── lines_og (original lines)
│       └── {tr,va,te} (.png)
└── lang (ground truth files)
    ├── char (space separated characters, <space> as delimiter)
    │   └── {tr,va,te}.gt
    ├── syms.txt (symbols file)
    └── word (word transcriptions)
        ├── {tr,va,te}.gt
        └── {tr,va,te}_tok.gt (tokenized words)

decode
├── char (character hypotheses, <space> as delimiter)
│   └── {va,te}.hyp
├── {va,te}_list.txt (lists of images to decode)
└── word (word hypotheses)
    ├── {va,te}.hyp
    └── {va,te}_tok.hyp (tokenized words)
```
