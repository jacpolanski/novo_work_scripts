// ==UserScript==
// @name         RCP style
// @namespace    http://tampermonkey.net/
// @version      0.1
// @description  try to take over the world!
// @author       You
// @match        https://rcp.novomatic-tech.com/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';
    var icons = document.createElement('link');
    icons.href="https://fonts.googleapis.com/icon?family=Material+Icons";
    icons.rel = "stylesheet";
    var font = document.createElement('link');
    font.href= "https://fonts.googleapis.com/css?family=Roboto:400,500&display=swap";
    font.rel = "stylesheet";
    var style = document.createElement('style');
    let newIcon = document.createElement('i');
    newIcon.innerText='account_circle';
    newIcon.className='material-icons userIcon'

    style.innerHTML = `
  html,body {
  background: #fbfbfb;font-family:Roboto!important;
  }
  .userIcon {font-size:36px;}
  #headTop {display:none}
  #contTop {display: none}
  .cap, .cap em {padding:0; font-family: Roboto; font-size:14px;font-weight:400;}
  .logoClass {font-size:24px;font-weight:500; padding-top:15px;padding-right:30px;float:left;}
  #headMenu { margin:0 auto;}
  #contents {margin-top:96px; border-radius: 2px; box-shadow: 0 1px 1px 0 rgba(0,0,0,0.14), 0 2px 1px -1px rgba(0,0,0,0.12), 0 1px 3px 0 rgba(0,0,0,0.2); padding:24px}
  #contContent, #contents, #contTop {width: auto; background-color: white; }
  #head {color: white;width:100%; position:fixed;left:0; top:0;height:56px;background-color:#2d4e7c}
  #headMenu, #headMenuLeft, #headMenuRight, #headMenuRight ul a {background:none; height:100%}
#headMenuLeft li{ height: 100%; font-size:14px;}
  #headMenuLeft li.chosen a{padding-top:21px; font-family:Roboto!important; font-weight:500; font-size:14px;background:none; color:white; border-bottom:2px solid white; height:100%; box-sizing:border-box;}
 #headMenuLeft li:not(.chosen) a{padding-top:21px; font-family:Roboto!important; font-weight:500; font-size:14px;background:none; color:white; opacity:0.7; height:100%; box-sizing:border-box;}
.material-icons {
  font-family: 'Material Icons';
  font-weight: normal;
  font-style: normal;
  font-size: 24px;  /* Preferred icon size */
  display: inline-block;
  line-height: 1;
  text-transform: none;
  letter-spacing: normal;
  word-wrap: normal;
  white-space: nowrap;
  direction: ltr;

  /* Support for all WebKit browsers. */
  -webkit-font-smoothing: antialiased;
  /* Support for Safari and Chrome. */
  text-rendering: optimizeLegibility;

  /* Support for Firefox. */
  -moz-osx-font-smoothing: grayscale;

  /* Support for IE. */
  font-feature-settings: 'liga';
}
.userIcon {font-size:36px!important;}
#headMenuRight ul li i{vertical-align:middle}
#headMenuRight ul li{font-size:16px;font-weight:400;font-family:roboto;padding-top:12px;}
#headMenuRight ul li:nth-child(2){display:none}
#headMenuRight ul li:nth-child(1){display:none;padding:0;color:rgba(0,0,0,0.87);position:absolute;top:56px;width:200px;background:white;border:0px solid black; border-radius:0 0 4px 4px; box-shadow:0 1px 1px 0 rgba(0,0,0,0.14), 0 2px 1px -1px rgba(0,0,0,0.12), 0 1px 3px 0 rgba(0,0,0,0.2);}
#headMenuRight ul li:nth-child(1) a{color:black;padding:10px;font-size:16px;font-weight:400;font-family:roboto;}
#headMenuRight ul li.visible:nth-child(1){display:inline-block}
#contContentLogin .indexInfo, #contContentLogin h2,#contContentLogin h3 {display:none}
#log {font-weight:400;height:auto; border-radius:4px; background:white;}
#footer,.TableRight, .TableLeft {display:none}
.forminput input.submit {background-image:none;background-color: rgb(34, 61, 100);color:white;padding:10px 26px; font-size:14px; font-family:Roboto; width:auto;height:auto;}
.forminput input[type=text],.forminput input[type=password]{ font-size: 14px; height:100%;width:100%;margin:0;padding: 8px; box-sizing: border-box;}
.rowbox span.forminput {height:50px;margin:20px;display:block;float:none!important;overflow:hidden;border:1px solid rgba(0,0,0,0.32)!important;border-radius:4px;}
#contContentForm{background:none;padding-left:none;}
#contContentForm .rowbox{padding-left:0;}
#contContentForm .rowbox, #contContentForm .rowbox .row,#contContentForm .row {width:auto;}
div.row span.forminput{float:none;} .row span input{margin:0;} #contContentForm .row {text-align:center;}
.row .formlabel{display:none;}
  `;
  document.head.appendChild(style);

    document.querySelector('#headMenuRight ul li:last-child').onclick= ()=>{document.querySelector('#headMenuRight ul li:nth-child(1)').classList.toggle('visible')}
    document.head.appendChild(font);
    document.head.appendChild(icons);
    let logo = document.createElement('span');
    logo.innerText= 'RCP';
    logo.classList.add('logoClass');
    let userMenu= document.querySelector('#headMenuRight');
    if(userMenu.children[0].children[2]) userMenu.children[0].children[2].appendChild(newIcon);

    let table = document.querySelector('.TableCenter');
    let content = document.querySelector('#contContent');
    let headMenu = document.querySelector('#headMenu');
     let mainTable = document.querySelector('#MainTable');
     let footer = document.querySelector('#footer');
    content.append(table.children[table.children.length==4?3:1])
    table.children[1]?content.append(table.children[1]):null
    headMenu.prepend(logo)
    mainTable.remove();
    footer.remove();
})();