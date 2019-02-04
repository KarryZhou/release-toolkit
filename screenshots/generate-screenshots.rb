#!/usr/bin/env ruby

require 'RMagick'
require 'json'
require 'tempfile'

include Magick

def canvas_with_device_frame(device)

    canvas_size = device["canvas_size"]

    canvas = Image.new(canvas_size[0], canvas_size[1]) {
        self.background_color = "#016087"
    }

    device_frame = Magick::Image.read(device["device_frame"]) {
        self.format = 'SVG'
        self.background_color = 'transparent'
    }.first

    canvas.composite(device_frame, SouthGravity, 0, 90, Magick::OverCompositeOp)
end

def add_caption_to_canvas(entry, canvas, device)

    text = entry["text"]
    text_size = device["text_size"]

    width = text_size[0]
    height = text_size[1]

    text_frame = Image.new(width, height) {
        self.background_color = 'transparent'
    }

    tempTextFile = Tempfile.new()

    begin

        unless system("./drawText.swift html=" + text + " maxWidth=#{width} maxHeight=#{height} output=#{tempTextFile.path}")
            abort()
        end

        text_content = Magick::Image.read(tempTextFile.path) {
            self.background_color = 'transparent'
        }.first

        text_frame.composite!(text_content, CenterGravity, Magick::OverCompositeOp)

        ensure
        tempTextFile.close
        tempTextFile.unlink
    end

    canvas.composite!(text_frame, NorthGravity, Magick::OverCompositeOp)
end

def draw_screenshot_to_canvas(entry, canvas, device)

    device_mask = device["screenshot_mask"]
    screenshot_size = device["screenshot_size"]
    screenshot_offset = device["screenshot_offset"]

    screenshot = entry["screenshot"]

    screenshot_mask = Magick::Image.read(device_mask).first

    screenshot = Magick::Image.read(screenshot) {
        self.background_color = 'transparent'
    }
    .first
    .composite(screenshot_mask, 0, 0, CopyOpacityCompositeOp)
    .adaptive_resize(screenshot_size[0], screenshot_size[1])

    x_offset = screenshot_offset[0]
    y_offset = screenshot_offset[1]

    canvas.composite(screenshot, NorthWestGravity, x_offset, y_offset, Magick::OverCompositeOp)
end

def draw_attachments_to_canvas(entry, canvas, shadowOffset)

    entry["attachments"].each { |attachment|

        file = attachment["file"]

        # Resize the images with extra size to account for the shadows
        size = attachment["size"].map{ |i| i + (shadowOffset * 2) }

        # Correct for the shadow offset by centering the image within the shadow bounds
        position = attachment["position"].map{ |i| i - shadowOffset }

        attachment_image = Magick::Image.read(file) {
            self.background_color = 'transparent'
        }
        .first
        .adaptive_resize(size[0], size[1])

        x = position[0]
        y = position[1]

        canvas.composite!(attachment_image, NorthWestGravity, x, y, Magick::OverCompositeOp)
    }

    return canvas
end

config = JSON.parse(open("screenshots.json").read)

devices = config["devices"]
names = devices.map { |device| device["name"] }

devices = Hash[names.zip(devices)]

config["entries"].each{ |entry|

    device = devices[entry["device"]]

    canvas = canvas_with_device_frame(device)
    canvas = add_caption_to_canvas(entry, canvas, device)
    canvas = draw_screenshot_to_canvas(entry, canvas, device)
    canvas = draw_attachments_to_canvas(entry, canvas, 40)

    canvas.write(entry["filename"])
}