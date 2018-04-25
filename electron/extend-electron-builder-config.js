const path = require('path')
const BASE = require(path.join(__dirname, 'electron-builder.json'))
const RESINCI_JSON = process.argv[2]
const APPLICATION_NAME = process.argv[3]

if (!RESINCI_JSON || !APPLICATION_NAME) {
  console.error(`Usage: ${process.argv[0]} <resinci.json> <application name>`)
  process.exit(1)
}

// See https://stackoverflow.com/a/34749873

const isObject = (item) => {
  return item && typeof item === 'object' && !Array.isArray(item)
}

const mergeDeep = (target, ...sources) => {
  if (!sources.length) return target
  const source = sources.shift()

  if (isObject(target) && isObject(source)) {
    for (const key in source) {
      if (isObject(source[key])) {
        if (!target[key]) Object.assign(target, { [key]: {} })
        mergeDeep(target[key], source[key])
      } else {
        if (Array.isArray(source[key]) && Array.isArray(target[key])) {
          target[key].push(...source[key])
        } else {
          Object.assign(target, { [key]: source[key] })
        }
      }
    }
  }

  return mergeDeep(target, ...sources)
}

const config = mergeDeep(BASE, require(RESINCI_JSON).electron.builder)
config.linux.executableName = APPLICATION_NAME
console.log(JSON.stringify(config, null, 2))
