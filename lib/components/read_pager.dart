// 翻页阅读容器组件

import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:seek_book/book_site/book_site.dart';
import 'package:seek_book/components/read_option_layer.dart';
import 'package:seek_book/components/read_pager_item.dart';
import 'package:seek_book/components/text_canvas.dart';
import 'package:seek_book/utils/screen_adaptation.dart';
import 'package:seek_book/globals.dart' as Globals;
import 'package:seek_book/utils/status_bar.dart';

class ReadPager extends StatefulWidget {
  final Map bookInfo;
  final GlobalKey<ReadOptionLayerState> optionLayerKey;

  ReadPager({
    Key key,
    @required this.bookInfo,
    this.optionLayerKey,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return ReadPagerState();
  }
}

int maxInt = 999999;

class ReadPagerState extends State<ReadPager> {
//  int maxInt = 999999999999999;

  var currentPageIndex = 0;
  var currentChapterIndex = 0;

//  var pageEndIndexList = [];

  Map<String, List> chapterPagerDataMap = Map(); //调整字体后需要清空,url为key
  Map<String, String> chapterTextMap =
      Map(); //章节内容缓存,已缓存到内存的章节，若没有则从网络和本地读取，url为key

  Map<int, bool> loadingMap = Map(); //章节加载状态，key为章节索引，value为true则为加载中

//  var content = "";

  TextStyle textStyle;
  double readTextWidth;
  double readTextHeight;
  double lineHeight;

  PageController pageController;

  int initScrollIndex = (maxInt / 2).floor();

//  int initPageIndex = 0;
//  int initChapterIndex = 0;

  @override
  void initState() {
    readTextWidth = ScreenAdaptation.screenWidth - dp(32);
    readTextHeight =
        ScreenAdaptation.screenHeight - dp(38) - dp(44); //减去头部章节名称高度，减去底部页码高度
    lineHeight = dp(27);
    print("lineHeight $lineHeight");
    var lineNum = (readTextHeight / lineHeight).floor();
//    lineHeight = (readTextHeight / lineNum).floorToDouble();
    lineHeight = (readTextHeight / lineNum);
    print("lineHeight $lineHeight");
    textStyle = buildTextStyle();

    List chapterList = widget.bookInfo['chapterList'];

    this.pageController = PageController(initialPage: initScrollIndex);
    this.pageController.addListener(() {
//      var currentPageIndex =
//          pageController.page - initScrollIndex + initPageIndex;
//      print(currentPageIndex);
      var currentPageIndexOffset = pageController.page;
//      print("currentPageIndexOffset  $currentPageIndexOffset");
      if (currentPageIndexOffset < currentPageIndexOffset.round() &&
          currentPageIndex == 0 &&
          currentPageIndexOffset.round() - currentPageIndexOffset < 0.3 &&
          currentChapterIndex == 0) {
//        print('currentPageIndexOffset.round() - currentPageIndexOffset  ${currentPageIndexOffset.round() - currentPageIndexOffset}');
        print("禁止滑动");
        pageController.jumpToPage(currentPageIndexOffset.round());
        return;
      }
//      print(
//          "$currentPageIndexOffset ${currentPageIndexOffset.round()} $currentPageIndex ${currentChapterIndex} ");
      if (currentPageIndexOffset > currentPageIndexOffset.round() &&
          currentPageIndexOffset - currentPageIndexOffset.round() < 0.3 &&
//          currentPageIndex == pageCount - 1 &&
//          currentChapterIndex == chapterList.length - 1) {
          currentPageIndex == 0 &&
          currentChapterIndex == chapterList.length) {
//        print('currentPageIndexOffset.round() - currentPageIndexOffset  ${currentPageIndexOffset.round() - currentPageIndexOffset}');
        print("禁止滑动");
        pageController.jumpToPage(currentPageIndexOffset.round());
        return;
      }

      widget.optionLayerKey.currentState.hide();
    });

    this.currentPageIndex = widget.bookInfo['currentPageIndex'];
    this.currentChapterIndex = widget.bookInfo['currentChapterIndex'];
    saveReadState();

//    var chapterList = widget.bookInfo['chapterList'];
    if (currentChapterIndex < chapterList.length) {
      loadingMap[currentChapterIndex] = true;
    }
    if (currentChapterIndex + 1 < chapterList.length) {
      loadingMap[currentChapterIndex + 1] = true;
    }
    if (currentChapterIndex - 1 >= 0) {
      loadingMap[currentChapterIndex - 1] = true;
    }
    this.initReadState();
    super.initState();
  }

  initReadState() async {
    await Future.delayed(Duration(milliseconds: 350));
    StatusBar.hide();

//    await Future.wait([
//      this.loadChapterText(currentChapterIndex, false),
//      this.loadChapterText(currentChapterIndex + 1, false),
//      this.loadChapterText(currentChapterIndex - 1, false),
//    ]);
    print("init build page ===》 $currentChapterIndex");

    this.loadChapterText(currentChapterIndex);
    this.loadChapterText(currentChapterIndex + 1);
    this.loadChapterText(currentChapterIndex - 1);
  }

  Future loadChapterText(chapterIndex, [bool reLayout = true]) async {
    print('loadChapterText');

    var chapterList = widget.bookInfo['chapterList'];
    if (chapterIndex < 0 || chapterIndex > chapterList.length - 1) {
      loadingMap.remove(chapterIndex); //不在章节索引中，移除加载状态
//      setState(() {});
//      print("$chapterIndex 越界");
      return;
    }
//    print("${chapterIndex} bu越界");
    loadingMap[chapterIndex] = true;
    var url = chapterList[chapterIndex]['url'];
    if (chapterTextMap[url] != null) {
      if (chapterPagerDataMap[url] != null &&
          chapterPagerDataMap[url].length == 0) {
        calcPagerData(url);
      }
      loadingMap.remove(chapterIndex); //从内存中加载，移除加载状态
      return;
    }
    print("loadChapterText =======");

    var database = Globals.database;
    List<Map> existData =
        await database.rawQuery('select text from chapter where id = ?', [url]);
    var content = '';
    if (existData.length > 0) {
      content = existData[0]['text'];
    } else {
      try {
        var siteRule = BookSite.findSiteRule(widget.bookInfo['siteHost']);
        content = await BookSite().parseChapter(url, siteRule);
        loadingMap.remove(chapterIndex); //并发以完成，移除加载状态
      } catch (e) {
        print(e);
        loadingMap[chapterIndex] = false;
        if (reLayout && this.mounted) {
          setState(() {});
        }
        return;
      }
    }
    chapterTextMap[url] = content;

    calcPagerData(url);
    loadingMap.remove(chapterIndex); //加载完成，移除加载状态

    if (reLayout && this.mounted) {
      setState(() {});
    }
  }

  calcPagerData(url) {
    var exist = chapterPagerDataMap[url];
    if (exist != null && exist.length > 0) {
      return exist;
    }
    if (chapterTextMap[url] == null) {
      return [0];
    }
//    var pageEndIndexList = parseChapterPager(chapterTextMap[url]);
    var pageEndIndexList = ChapterTextPainter.calcPagerData(
      chapterTextMap[url],
      readTextWidth,
      readTextHeight,
      textStyle,
      lineHeight,
    );
    chapterPagerDataMap[url] = pageEndIndexList;
//    print(pageEndIndexList);
//    print("页数 ${pageEndIndexList.length}");
    return pageEndIndexList;
  }

  var preScrollNotify;

  bool onPageScrollNotify(Notification notification) {
//    print(notification.runtimeType);
    if (notification is UserScrollNotification &&
        preScrollNotify is ScrollEndNotification) {
      //滚动自动停止

      var index = pageController.page.round();
      initScrollIndex = index;

      this.saveReadState();

      /// 若已经处于加载状态，忽略重复加载请求
      if (loadingMap[currentChapterIndex + 1] != true) {
        this.loadChapterText(currentChapterIndex + 1);
      }
      if (loadingMap[currentChapterIndex - 1] != true) {
        this.loadChapterText(currentChapterIndex - 1);
      }
    }
    preScrollNotify = notification;
    return false;
  }

  saveReadState() async {
    var database = Globals.database;
    await database.update(
      'Book',
      {
        "currentPageIndex": this.currentPageIndex,
        "currentChapterIndex": this.currentChapterIndex,
        "hasNew": 0,
      },
      where: "name=? and author=?",
      whereArgs: [widget.bookInfo['name'], widget.bookInfo['author']],
    );
  }

  @override
  Widget build(BuildContext context) {
    var newReadTextWidth = vw(100) - dp(32);
    if (readTextWidth != newReadTextWidth) {
      chapterPagerDataMap = Map(); //调整字体后需要清空,url为key
    }
    readTextWidth = newReadTextWidth;
    readTextHeight = vh(100) - dp(38) - dp(44); //减去头部章节名称高度，减去底部页码高度
    lineHeight = dp(27);
    var lineNum = (readTextHeight / lineHeight).floor();
//    lineHeight = (readTextHeight / lineNum).floorToDouble();
    lineHeight = (readTextHeight / lineNum);
    textStyle = buildTextStyle();

    print("build  hole  page !!!!! ${Platform.operatingSystem}");
    var pageView = new PageView.builder(
      onPageChanged: (index) {
        print('onPageChanged');
        var pageChange = index - initScrollIndex;
        var newPageIndex = currentPageIndex + pageChange;
        print("pagechange $pageChange");
        if (pageChange > 0) {
          List chapterList = widget.bookInfo['chapterList'];
          var url = chapterList[currentChapterIndex]['url'];
          var chapterPagerList = chapterPagerDataMap[url];
          if (chapterPagerList == null ||
              newPageIndex > chapterPagerList.length - 1) {
            currentPageIndex = 0;
            currentChapterIndex++;
          } else {
            currentPageIndex = newPageIndex;
          }
        } else {
          if (newPageIndex < 0) {
            List chapterList = widget.bookInfo['chapterList'];
            var url = chapterList[currentChapterIndex - 1]['url'];
            var chapterPagerList = chapterPagerDataMap[url];
            currentChapterIndex--;
            if (chapterPagerList == null || chapterPagerList.length == 0) {
              currentPageIndex = 0;
            } else {
              currentPageIndex = chapterPagerList.length - 1;
            }
          } else {
            currentPageIndex = newPageIndex;
          }
        }
        print("页码 $currentPageIndex,  章节 $currentChapterIndex");
        initScrollIndex = index;
      },
      controller: pageController,
      itemBuilder: (BuildContext context, int index) {
        return buildPage(index);
      },
      itemCount: maxInt,
      physics: ClampingScrollPhysics(),
//      physics: PagerScrollPhysics(),
    );
    return NotificationListener(
      child: Listener(
        child: pageView,
        onPointerDown: (point) {
          downPoint = point.position;
        },
        onPointerMove: (point) {
          downPoint = Offset(-1.0, -1.0);
        },
        onPointerUp: (point) {
          if (downPoint == null) return;
          if (pageController.page.round() != pageController.page) return;
          if (downPoint.dx == point.position.dx) {
            //点击到重试按钮，忽略此次点击。
            if (reloadButtonClick) {
              reloadButtonClick = false;
              return;
            }
            //点击释放
            // 判断点击位置，弹出option或翻页
            widget.optionLayerKey.currentState.toggleShow();
          } else {
            //拖动释放
          }
        },
//        onTap: (){},
      ),
      onNotification: onPageScrollNotify,
    );
  }

  TextStyle buildTextStyle() {
    return new TextStyle(
      height: 1.0,
      fontSize: dp(18),
      letterSpacing: dp(1),
      fontFamily: 'ReadFont',
      color:
          Globals.readTheme == 'normal' ? Color(0xff383635) : Color(0xffFFFFFF),
    );
  }

  Offset downPoint;

  String loadPageText(url, int pageIndex) {
    var pageEndIndexList = chapterPagerDataMap[url];
    var chapterText = chapterTextMap[url];
    if (pageEndIndexList == null || chapterText == null) {
      return "";
    }
    return chapterText.substring(
      pageIndex == 0 ? 0 : pageEndIndexList[pageIndex - 1],
      pageEndIndexList[pageIndex],
    );
  }

  Widget buildPage(int index) {
//    print("buildPage========");
    var blankPage = false;
    var finishPage = false;
    var pageIndex = currentPageIndex + (index - initScrollIndex);
    var chapterIndex = currentChapterIndex;
    List chapterList = widget.bookInfo['chapterList'];

//    print("++++++++++++ ${chapterIndex}");

//    print("build page ===》 $chapterIndex   index => $index/$initScrollIndex");

    var url;
    var title;
    if (chapterIndex < chapterList.length) {
      var chapter = chapterList[chapterIndex];
      url = chapter['url'];
      title = chapter['title'];
    }

    var loading = loadingMap[chapterIndex];
//    print("加载状态 $chapterIndex  $loading  最多章节数量${chapterList.length}");
//    print("loadingggggggggggggggg   $loading $chapterIndex");
    if (loading == null) {
      print("load A   $chapterIndex");
//      print("aaaaaaaaaaa , $chapterIndex, ${chapterList.length}");

      var pageCount = calcPagerData(url).length;

//      print(
//          '加载页 $pageIndex,  章节$currentChapterIndex, $title, , $pageCount');

      if (pageIndex > pageCount - 1) {
        print("load AA");
//        print("${chapterIndex}  ${chapterList.length}");
        if (chapterIndex + 1 > chapterList.length - 1) {
          print("load AAA");
          finishPage = true;
//          break;
          //越界停止
        } else {
          print("load AAB");
          //当前章节有内容，且分页数大于0才参与多次分页
          chapterIndex++;
          pageIndex -= pageCount;
          //翻页超过本章最后一页，加载下一章，并计算页数
          print("NNNNN $pageIndex  , $pageCount ");
          var url = chapterList[chapterIndex]['url'];
          var parseChapterPagerList = calcPagerData(url);
          pageCount = parseChapterPagerList.length;
          print(parseChapterPagerList);
          // 这一页是否已加载失败
          var preLoading = loadingMap[chapterIndex];
          if (preLoading == false) {
            loading = preLoading;
          }
        }
      }
      if (pageIndex < 0) {
        print("load AB");
        if (chapterIndex - 1 < 0) {
          print("load ABA");
          blankPage = true;
//          break;
          //越界停止
        } else {
          print("load ABB");
          print("PPPPPPPPPPP  ${chapterIndex - 1}");
          chapterIndex--;
          var url = chapterList[chapterIndex]['url'];
          pageCount = calcPagerData(url).length;
          pageIndex += pageCount;
          // 这一页是否已加载失败
          var preLoading = loadingMap[chapterIndex];
          if (preLoading == false) {
            loading = preLoading;
          }
        }
      }
    } else {
      print("load B");
      //加载失败或加载中时，若翻页，则跳章节，
      if (pageIndex > 0 && pageIndex != currentPageIndex) {
        print("load BA");
        if (chapterIndex + 1 > chapterList.length - 1) {
          print("load BAA");
          finishPage = true;
          title = "";
          //越界停止
        } else {
          print("load BAB");
          chapterIndex++;
          pageIndex = 0;
          var chapter = chapterList[chapterIndex];
          title = chapter['title'];
          // 这一页是否已完成加载，若已完成加载，则直接读取
          var preLoading = loadingMap[chapterIndex];
          if (preLoading == null) {
            loading = preLoading;
          }
        }
      }
      if (pageIndex < 0) {
        print("load BB");
        if (chapterIndex - 1 < 0) {
          print("load BBA");
          blankPage = true;
          //越界停止
        } else {
          print("load BBB");
          chapterIndex--;
          pageIndex = 0;
          var chapter = chapterList[chapterIndex];
          title = chapter['title'];
          // 这一页是否已完成加载，若已完成加载，则直接读取
          var preLoading = loadingMap[chapterIndex];
          if (preLoading == null) {
            loading = preLoading;
            var url = chapter['url'];
            var pageCount = calcPagerData(url).length;
            if (pageCount > 0) {
              pageIndex = pageCount - 1;
            }
          }

//          //如果是从完结提示页向左滑，则加载上一章最后一页
//          print('$currentChapterIndex,  ${chapterList.length}');
//          if (currentChapterIndex == chapterList.length) {
//            var url = chapterList[chapterIndex]['url'];
//            var chapterPagerList = chapterPagerDataMap[url];
//            print("取 章节 ${chapterIndex - 1}  ${chapterPagerList}");
//            if (chapterPagerList == null || chapterPagerList.length == 0) {
//              pageIndex = 0;
//            } else {
//              pageIndex = chapterPagerList.length - 1;
//              loading = null;
//            }
//          }
        }
      }
    }

    var text = "";
    var pageLabel = "";

    Widget contentWidget = Container();

    if (blankPage) {
      text = '越界了';
      pageLabel = '';
      title = '';
    } else if (finishPage || chapterIndex > chapterList.length - 1) {
//      print("${chapterIndex}, 没有最新章节");
      text = '没有最新章节';
      pageLabel = '';
      title = '';
      contentWidget = buildTextCanvas(text);
    } else if (loading == true) {
      text = '加载中1';
      pageLabel = '';
      title = title ?? '';
      contentWidget = Container(
        child: CupertinoActivityIndicator(
          radius: dp(20),
        ),
      );
    } else if (loading == false) {
      print("失败!!!");
      text = '加载失败';
      pageLabel = '';
      title = title ?? '';
      contentWidget = buildFailView();
    } else {
      var chapter = chapterList[chapterIndex];
      var url = chapter['url'];
      title = chapter['title'];
      var pageEndIndexList = chapterPagerDataMap[url];
      print(title + "  $pageEndIndexList");
//      print('bbbbbbb ${chapterIndex}  ${url}');
      if (pageEndIndexList != null && pageEndIndexList.length > 0) {
        text = loadPageText(url, pageIndex);
        pageLabel = '${pageIndex + 1}/${pageEndIndexList.length}';
        contentWidget = buildTextCanvas(text);
      } else {
        //最初始化的加载，没有在加载状态中
        title = chapterList[chapterIndex]['title'];
//        title = '123123-----$currentPageIndex';
        text = "加载中2";
//        contentWidget = buildTextCanvas(text);
        contentWidget = Container(
          child: CupertinoActivityIndicator(
            radius: dp(20),
          ),
        );
      }
    }
//    print("++++++++++++ ${chapterIndex}");

    return ReadPagerItem(
      text: contentWidget,
      title: title,
      pageLabel: pageLabel,
    );
  }

  TextCanvas buildTextCanvas(String text) {
    return new TextCanvas(
      text: text,
      width: readTextWidth,
      height: readTextHeight,
      lineHeight: lineHeight,
      // 阅读文字颜色
      style: textStyle,
//      color:
//          Globals.readTheme == 'normal' ? Color(0xff383635) : Color(0xffFFFFFF),
    );
  }

  var reloadButtonClick = false;
  var reloadButtonDown = false;

  Widget buildFailView() {
    return new Container(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('加载失败'),
            Listener(
              child: RaisedButton(
                child: Text("重试"),
                onPressed: () {},
              ),
              onPointerUp: (event) {
                reloadButtonClick = true;
                if (reloadButtonDown) {
                  print("reload 6666666");
                  setState(() {
                    loadChapterText(currentChapterIndex);
                  });
                }
              },
              onPointerDown: (e) {
                reloadButtonDown = true;
              },
              onPointerMove: (e) {
                reloadButtonDown = false;
              },
              onPointerCancel: (e) {
                reloadButtonDown = false;
              },
            ),
          ],
        ),
      ),
    );
  }

  changeChapter(chapterIndex) {
    setState(() {
      currentChapterIndex = chapterIndex;
      currentPageIndex = 0;
    });
    loadChapterText(chapterIndex);
  }
}
