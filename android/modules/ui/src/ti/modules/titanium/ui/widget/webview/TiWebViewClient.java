/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2010 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

package ti.modules.titanium.ui.widget.webview;

import org.appcelerator.titanium.TiDict;
import org.appcelerator.titanium.util.Log;
import org.appcelerator.titanium.util.TiConfig;

import ti.modules.titanium.ui.WebViewProxy;
import android.content.Intent;
import android.graphics.Bitmap;
import android.net.Uri;
import android.webkit.HttpAuthHandler;
import android.webkit.URLUtil;
import android.webkit.WebView;
import android.webkit.WebViewClient;

public class TiWebViewClient extends WebViewClient
{
	private static final String LCAT = "TiWVC";
	private static final boolean DBG = TiConfig.LOGD;
	private WebViewProxy proxy;
	private WebView webView;
	private TiWebViewBinding binding;

	private String username, password;
	
	public TiWebViewClient(WebViewProxy proxy, WebView webView) {
		super();
		this.proxy = proxy;
		this.webView = webView;
		binding = new TiWebViewBinding(proxy.getTiContext(), webView);
	}

	@Override
	public void onPageFinished(WebView view, String url) {
		super.onPageFinished(view, url);

		TiDict data = new TiDict();
		data.put("url", url);
		proxy.fireEvent("load", data);
	}

	public TiWebViewBinding getBinding() {
		return binding;
	}

	@Override
	public void onReceivedError(WebView view, int errorCode, String description, String failingUrl)
	{
		super.onReceivedError(view, errorCode, description, failingUrl);

		//TODO report this to the user
		String text = "Javascript Error("+errorCode+"): " + description;
		Log.e(LCAT, "Received on error" + text);
	}

	@Override
	public boolean shouldOverrideUrlLoading(final WebView view, String url) {
		if (DBG) {
			Log.d(LCAT, "url=" + url);
		}

		if (URLUtil.isAssetUrl(url) || URLUtil.isContentUrl(url) || URLUtil.isFileUrl(url)) {
			// go through the proxy to ensure we're on the UI thread
			proxy.setDynamicValue("url", url);
			return true;
		} else if(url.startsWith(WebView.SCHEME_TEL)) {
			Log.i(LCAT, "Launching dialer for " + url);
			Intent dialer = Intent.createChooser(new Intent(Intent.ACTION_DIAL, Uri.parse(url)), "Choose Dialer");
			proxy.getTiContext().getActivity().startActivity(dialer);
	        return true;
		} else if (url.startsWith(WebView.SCHEME_MAILTO)) {
			Log.i(LCAT, "Launching mailer for " + url);
			Intent mailer = Intent.createChooser(new Intent(Intent.ACTION_SENDTO, Uri.parse(url)), "Send Message");
			proxy.getTiContext().getActivity().startActivity(mailer);
	        return true;
		} else if (url.startsWith(WebView.SCHEME_GEO)) {
			Log.i(LCAT, "Launching app for " + url);
			/*geo:latitude,longitude
			geo:latitude,longitude?z=zoom
			geo:0,0?q=my+street+address
			geo:0,0?q=business+near+city
			*/
			Intent geoviewer = Intent.createChooser(new Intent(Intent.ACTION_VIEW, Uri.parse(url)), "Choose Viewer");
			proxy.getTiContext().getActivity().startActivity(geoviewer);
			return true;
		} else {
			if (DBG) {
				Log.e(LCAT, "NEED to Handle " + url);
			}
		}

		return false;
	}
	
	@Override
	public void onReceivedHttpAuthRequest(WebView view,
			HttpAuthHandler handler, String host, String realm) {
		
		if (this.username != null && this.password != null) {
			handler.proceed(this.username, this.password);
		}
	}
	
	public void setBasicAuthentication(String username, String password) {
		this.username = username;
		this.password = password;
	}
}
