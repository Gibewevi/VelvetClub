class_name TrafficChart
extends Control

var series: Array = []
var secondary: Array = []
var labels: Array = []
var main_name = "Arrivées"
var other_name = "Entrées"
var color = Color("e0b65c")
var other_color = Color("df7798")
var ceiling = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(220*UiKit.scale,102*UiKit.scale)

func _draw() -> void:
	if series.is_empty(): return
	var s = UiKit.scale
	var font = UiKit.theme.default_font
	var fs = UiKit.fs(1)
	var plot = Rect2(24*s,5*s,maxf(10,size.x-29*s),72*s)
	var maximum = maxf(1,ceiling)
	for value in series+secondary: maximum = maxf(maximum,float(value))
	maximum = ceil(maximum)
	for fraction in [0.0,.5,1.0]:
		var y = roundf(plot.end.y-fraction*plot.size.y)
		draw_rect(Rect2(plot.position.x,y,plot.size.x,s),Color("393342"))
		draw_string(font,Vector2(0,y+4*s),str(int(maximum*fraction)),HORIZONTAL_ALIGNMENT_LEFT,-1,fs,UiKit.MUTED)
	var width = plot.size.x/series.size()
	for i in series.size():
		var x = roundf(plot.position.x+i*width)
		var gap = 6 if series.size() > 12 else 1
		if i%gap == 0 or i == series.size()-1:
			draw_string(font,Vector2(x,plot.end.y+13*s),str(labels[i]) if i < labels.size() else str(i),HORIZONTAL_ALIGNMENT_LEFT,-1,fs,UiKit.MUTED)
		if float(series[i]) < 0:
			draw_rect(Rect2(x+2*s,plot.end.y-2*s,maxf(s,width-3*s),s),UiKit.DIM)
			continue
		var bar_width = maxf(s,floorf((width-2*s)/(2 if not secondary.is_empty() else 1)/s)*s)
		var h = roundf(maxf(0,series[i])/maximum*plot.size.y/s)*s
		draw_rect(Rect2(x+s,plot.end.y-h,bar_width,h),color)
		if i < secondary.size():
			var height = roundf(maxf(0,secondary[i])/maximum*plot.size.y/s)*s
			draw_rect(Rect2(x+s+bar_width,plot.end.y-height,bar_width,height),other_color)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not series.is_empty():
		var s = UiKit.scale
		var index = clampi(floori((event.position.x-24*s)/maxf(1,size.x-29*s)*series.size()),0,series.size()-1)
		var label = str(labels[index]) if index < labels.size() else str(index)
		tooltip_text = label+" · "+(main_name+" : %.1f" % float(series[index]) if series[index] >= 0 else "Pas encore mesuré")
		if index < secondary.size() and series[index] >= 0: tooltip_text += " · %s : %.1f" % [other_name,float(secondary[index])]
