/*
   Copyrights (C) 2008 David Esperalta <davidesperalta@gmail.com>

   This file is part of StyleSwichter jQuery plugin for jQuery

   StyleSwichter is free software: you can redistribute it and/or 
   modify it under the terms of the GNU General Public License as 
   published by the Free Software Foundation, either version 3 of 
   the License, or (at your option) any later version.

   StyleSwichter is distributed in the hope that it will be useful, 
   but WITHOUT ANY WARRANTY; without even the implied warranty of 
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
   General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with StyleSwichter. If not, see <http://www.gnu.org/licenses/>.

*/

/*
   --------------------------------------
   StyleSwichter jQuery plugin for jQuery
   --------------------------------------
  
   Please, use the "example.html" and source code to more information
   about how use this plugin. Thanks very much for your interest.
   
   Plugin tested in Firefox 2, Opera 9, IExplorer 7 and Safari 3
   
   This plugin assume the existence of Cookie jQuery plugin. This not
   is an optional plugin, Cookie jQuery plugin must be require in order
   of use StyleSwichter plugin.
   
   For information and download visit my weblog:
   
   http://www.bitacora.davidesperalta.com/
     
   Thanks so much too Mike Alsup for their article jQuery plugin 
   pattern: learningjquery.com/2007/10/a-plugin-development-pattern 
    
*/

(function($){

  $.fn.StyleSwichter = function(options){
    var opts = $.extend({}, $.fn.StyleSwichter.defaults, options);
    var o = $.meta ? $.extend({}, opts, $this.data()) : opts;
    $('link').each(function(i){
      if(this.rel == 'stylesheet' && this.title == o.linkTitle){
        if(o.cssPath != ''){
          this.href = o.cssPath;
          $.cookie(o.cookieName,this.href,{
            path: o.cookiePath,
            expires: o.cookieDays,
            domain: o.cookieDomain,
            secure: o.cookieSecure
          });
        }else if($.cookie(o.cookieName)){
          this.href = $.cookie(o.cookieName);
        }
        return true;
      }
    });
    return false;
  };
  
  $.fn.StyleSwichter.defaults={
    cssPath: '',
    cookieDays: 30,
    cookiePath: '/',
    cookieDomain: '',
    cookieSecure: false,
    linkTitle: 'styleswichter',
    cookieName: 'selected-style'
  };

})(jQuery);
