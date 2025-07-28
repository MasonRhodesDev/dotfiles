import { create } from 'xmlbuilder2';
import { XMLBuilder } from 'xmlbuilder2/lib/interfaces';


export class XMLDesktopWallpaper {
    private doc: XMLBuilder
    
    constructor() {
        this.doc = create().ele("background")       
    }

    addStartTime(date:Date) {
        this.doc.ele("starttime")
            .ele("year").txt(date.getFullYear().toString()).up()
            .ele("month").txt((date.getMonth() + 1).toString()).up()
            .ele("day").txt(date.getDate().toString()).up()
            .ele("hour").txt(date.getHours().toString()).up()
            .ele("minute").txt(date.getMinutes().toString()).up()
            .ele("second").txt(date.getSeconds().toString()).up()
            .up();
    }
    
    addImage(uri: string, duration: number, transition?: number) {
        if (transition) {
            const last = this.doc.last()
            if (last.node.nodeName !== "static") {
                throw new Error("Transition can only be used after a static image");
            }
            const lastImageUri = last.node?.lastChild?.lastChild?.nodeValue;
            if (!lastImageUri) {
                throw new Error("Transition can only be used after a static image");
            }
            this.doc.last().ele("transition")
                .ele("duration").txt(transition.toString()).up()
                .ele("from").txt(lastImageUri).up()
                .ele("to").txt(uri).up()
                .up();
        }
        this.doc.ele("static")
            .ele("duration").txt(duration.toString()).up()
            .ele("file").txt(uri).up()
            .up();
    }

    toString() {
        return this.doc.end({ prettyPrint: true });
    }
}

export function generateWallpaperRecord(path: string) {
    const name = path.split("/").pop();
    if (!name) {
        throw new Error("Invalid path");
    }
    const doc = create().ele("wallpapers")
        .ele("wallpaper").att("deleted", "false")
            .ele("name").txt(name).up()
            .ele("filename").txt(path).up()
            .ele("options").txt("zoom").up()
    return doc.end({ prettyPrint: true });
}