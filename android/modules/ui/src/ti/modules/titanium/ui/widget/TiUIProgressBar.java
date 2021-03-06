/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2010 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */
package ti.modules.titanium.ui.widget;

import org.appcelerator.titanium.TiDict;
import org.appcelerator.titanium.TiProxy;
import org.appcelerator.titanium.proxy.TiViewProxy;
import org.appcelerator.titanium.util.TiConvert;
import org.appcelerator.titanium.view.TiUIView;

import android.view.Gravity;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;

public class TiUIProgressBar extends TiUIView {

	private TextView label;
	private ProgressBar progress;
	private LinearLayout view;
	
	public TiUIProgressBar(TiViewProxy proxy)
	{
		super(proxy);
		
		view = new LinearLayout(proxy.getContext());
		view.setOrientation(LinearLayout.VERTICAL);
		label = new TextView(proxy.getContext());
		label.setGravity(Gravity.TOP | Gravity.LEFT);
		label.setPadding(0, 0, 0, 0);
		label.setSingleLine(false);

		progress = new ProgressBar(proxy.getContext(), null, android.R.attr.progressBarStyleHorizontal);
		progress.setIndeterminate(false);
		progress.setMax(1000);
		
		view.addView(label);
		view.addView(progress);
		
		setNativeView(view);
	}
	
	@Override
	public void processProperties(TiDict d) {
		super.processProperties(d);
		
		if (d.containsKey("message")) {
			handleSetMessage(TiConvert.toString(d, "message"));
		}
		updateProgress();
	}
	
	@Override
	public void propertyChanged(String key, Object oldValue, Object newValue,
			TiProxy proxy) {
		super.propertyChanged(key, oldValue, newValue, proxy);
		
		if (key.equals("value") || key.equals("min") || key.equals("max")) {
			updateProgress();
		}
	}
	
	private double getMin() {
		Object value = proxy.getDynamicValue("min");
		if (value == null) {
			return 0;
		}
		
		return TiConvert.toDouble(value);
	}
	
	private double getMax() {
		Object value = proxy.getDynamicValue("max");
		if (value == null) {
			return 0;
		}
		
		return TiConvert.toDouble(value);
	}
	
	private double getValue() {
		Object value = proxy.getDynamicValue("value");
		if (value == null) {
			return 0;
		}
		
		return TiConvert.toDouble(value);
	}
	
	private int convertRange(double min, double max, double value, int base)
	{
		return (int)Math.floor((value/(max - min))*base);
	}
	
	public void updateProgress()
	{
		progress.setProgress(convertRange(getMin(), getMax(), getValue(), 1000));
	}
	
	public void handleSetMessage(String message)
	{
		label.setText(message);
		label.requestLayout();
	}
}
