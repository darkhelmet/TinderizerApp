/*
    Scala implementation of the Readability algorithm by Arc90

    As of the initial writing, this is essentially copy/pasted
    from the Arc90 readability.js project (v1.7.1), and edited to be valid scala.

    Further refactoring will ensue to improve the algorithm,
    and make the code more "scala-ish".

    Original code released under Apache 2.0 license, with full notice
    appearing in the readability.js file in this repo.
*/

package com.darkhax

import scala.collection.JavaConversions._
import scala.util.matching.Regex

import org.jsoup.Jsoup
import org.jsoup.nodes.Element

object Readability {
    val regexes = Map(
        "unlikely"  -> "(?i)combx|comment|community|disqus|extra|foot|header|menu|remark|rss|shoutbox|sidebar|sponsor|ad-break|agegate|pagination|pager|popup|tweet|twitter".r,
        "maybe"     -> "(?i)and|article|body|column|main|shadow".r,
        "positive"  -> "(?i)article|body|content|entry|hentry|main|page|pagination|post|text|blog|story".r,
        "negative"  -> "(?i)combx|comment|com-|contact|foot|footer|footnote|masthead|media|meta|outbrain|promo|related|scroll|shoutbox|sidebar|sponsor|shopping|tags|tool|widget".r,
        "scoreable" -> "(?i)p|td|pre".r
    )

    // Jsoup doesn't have a way to create just a node it seems,
    // so parse a fragment, then grab the node we want.
    def createElement(tag : String) = {
        Jsoup.parseBodyFragment("<" + tag + "/>").getElementsByTag(tag).head
    }
}

class Readability(url : String) {
    val doc = Jsoup.connect(url).get

    // DO IT!
    def summary() : (Element, Element) = {
        removeScripts()

        // TODO: Handle multiple pages

        prepareDocument()

        val div = Readability.createElement("div")
        val title = extractTitle()
        val content = extractArticle(doc.clone)

        content match {
            case None          => (null, null)
            case Some(article) => {
                div.appendChild(title)
                div.appendChild(article)

                postProcessContent(div)

                // TODO: Handle multiple pages

                (div, title)
            }
        }
    }

    private def postProcessContent(elem : Element) {
        // Not sure I have to actually do anything in here
        // Only thing I might have to do is fixing floating images
    }

    // Remove <script> tags
    private def removeScripts() {
        removeTags("script")
    }

    // Some basic prep work, like removing things we don't care about
    private def prepareDocument() {
        // Let's just remove frames. Fuck frames.
        // Remove all <link> and <style> tags as well. Fuck 'em I say!
        removeTags("frame", "link", "style")

        // TODO: Change double <br/> tags to <p> tags
    }

    private def extractArticle(page : Element, shouldStripUnlikely : Boolean = true, shouldScoreClasses : Boolean = true, shouldCleanConditionally : Boolean = true) : Option[Element] = {
        val body = page.getElementsByTag("body").head
        if (shouldStripUnlikely) {
            removeUnlikelyElements(body)
        }
        val nodesToScore = getNodesToScore(body)
        // TODO: Figure out why this doesn't work exploding the params
        val candidates = scoreElements(nodesToScore, shouldScoreClasses).map { pair =>
            (pair._1, pair._2  * (1 - getLinkDensity(pair._1)))
            // (elem, score * (1 - getLinkDensity(elem)))
        }
        val (topCandidate, topScore) = candidates.toList.sortBy(_._2).head

        // TODO: Handle this case
        // if (!top) {
        //     use body
        // }

        val article = Readability.createElement("div")
        appendPotentials(article, candidates, topCandidate, topScore)

        prepareArticle(article, candidates, shouldCleanConditionally, shouldScoreClasses)

        if (article.text.length < 250) {
            if (shouldStripUnlikely) {
                return extractArticle(doc.clone, false)
            } else if (shouldScoreClasses) {
                return extractArticle(doc.clone, false, false)
            }  else if (shouldCleanConditionally) {
                return extractArticle(doc.clone, false, false, false)
            } else {
                return None
            }
        }

        Some(article)
    }

    private def getLinkDensity(elem : Element) : Double = {
        val textLength = elem.text.length
        val linkLength = elem.getElementsByTag("a").foldLeft(0.0)((total, link) => total + link.text.length)
        linkLength / textLength
    }

    private def prepareArticle(article : Element, candidates : scala.collection.mutable.Map[Element, Double], shouldCleanConditionally : Boolean, shouldScoreClasses : Boolean) {
        removeStyleAttributes(article)
        // killExtraBreaks

        // Clean out junk from the article content
        cleanConditionally(article, candidates, "form", shouldCleanConditionally, shouldScoreClasses)

        clean(article, "object")
        clean(article, "embed")
        clean(article, "h1")

        // If there is only one h2, they are probably using it as a header and not a subheader,
        // so remove it since we already have a header.
        if (article.getElementsByTag("h2").length == 1) {
            clean(article, "h2")
        }

        clean(article, "iframe")
        cleanHeaders(article, shouldScoreClasses)

        // Do these last as the previous stuff may have removed junk that will affect these
        cleanConditionally(article, candidates, "table", shouldCleanConditionally, shouldScoreClasses)
        cleanConditionally(article, candidates, "ul", shouldCleanConditionally, shouldScoreClasses)
        cleanConditionally(article, candidates, "div", shouldCleanConditionally, shouldScoreClasses)

        removeExtraParagraphs(article)

        // try {
        //     articleContent.innerHTML = articleContent.innerHTML.replace(/<br[^>]*>\s*<p/gi, '<p');
        // }
        // catch (e) {
        //     dbg("Cleaning innerHTML of breaks failed. This is an IE strict-block-elements bug. Ignoring.: " + e);
        // }
    }

    private def cleanHeaders(elem : Element, shouldScoreClasses : Boolean) {
        List("h1", "h2").foreach { tag =>
            elem.getElementsByTag(tag).foreach { e =>
                if (scoreClasses(e, shouldScoreClasses) < 0 || getLinkDensity(e) > 0.33) {
                    e.remove
                }
            }
        }
    }

    private def removeStyleAttributes(elem : Element) {
        elem.getAllElements.foreach(e => e.removeAttr("style"))
    }

    private def removeExtraParagraphs(elem : Element) {
        elem.getElementsByTag("p").foreach { e =>
            lazy val zeroImages = getTagCount(e, "img") == 0
            lazy val zeroEmbeds = getTagCount(e, "embed") == 0
            lazy val zeroObjects = getTagCount(e, "object") == 0
            lazy val noText = e.text.trim.length == 0
            if (zeroImages && zeroEmbeds && zeroObjects && noText) {
                e.remove
            }
        }
    }

    private def clean(elem : Element, tags : String*) {
        tags.foreach { tag =>
            elem.getElementsByTag(tag).foreach(_.remove)
        }
    }

    private def cleanConditionally(elem : Element, candidates : scala.collection.mutable.Map[Element, Double], tag : String, shouldCleanConditionally : Boolean, shouldScoreClasses : Boolean) {
        if (shouldCleanConditionally) {
            elem.getElementsByTag(tag).foreach { e =>
                val weight = scoreClasses(e, shouldScoreClasses)
                val contentScore = candidates.get(e).getOrElse(0.0)

                if (weight + contentScore < 0) {
                    e.remove
                } else if (getCharCount(e.text, ",") < 10) {
                    // If there are not very many commas, and the number of
                    // non-paragraph elements is more than paragraphs or other ominous signs, remove the element.

                    // TODO: Fix these to use lazy vals
                    val pCount = getTagCount(e, "p")
                    val imgCount = getTagCount(e, "img")
                    val liCount = getTagCount(e, "li") - 100
                    val inputCount = getTagCount(e, "input")
                    val embedCount = getTagCount(e, "embed")
                    val linkDensity = getLinkDensity(e)
                    val contentLength = e.text.length

                    val moreImagesThanParagraphs = imgCount > pCount
                    val moreLiThanParagraphs = liCount > pCount
                    val tagNotList = e.tagName != "ul" && e.tagName != "ol"
                    val moreInputsThanParagraphs = inputCount > scala.math.floor(pCount.toFloat / 3)
                    val shortContentAndNoOrManyImages = contentLength < 25 && (imgCount == 0 || imgCount > 2)
                    val lowWeightAndDecentLinkDensity = weight < 25 && linkDensity > 0.2
                    val highWeightAndHighLinkDensity = weight >= 25 && linkDensity > 0.5
                    val singleEmbedLowContentOrManyEmbeds = (embedCount == 1 && contentLength < 75) || embedCount > 1

                    val shouldRemove = (moreImagesThanParagraphs ||
                                        (moreLiThanParagraphs && tagNotList) ||
                                        moreInputsThanParagraphs ||
                                        shortContentAndNoOrManyImages ||
                                        lowWeightAndDecentLinkDensity ||
                                        highWeightAndHighLinkDensity ||
                                        singleEmbedLowContentOrManyEmbeds)
                    if (shouldRemove) {
                        e.remove
                    }
                }
            }
        }
    }

    private def getTagCount(elem : Element, tag : String) : Int = {
        elem.getElementsByTag(tag).length
    }

    private def getCharCount(s : String, c : String) : Int = {
        c.split(c).length - 1
    }

    private def appendPotentials(article : Element, candidates : scala.collection.mutable.Map[Element, Double], topCandidate : Element, topScore : Double) {
        val siblingThreshold = scala.math.max(10, topScore * 0.2)
        topCandidate.siblingElements.foreach { sibling =>
            var append = false
            if (sibling == topCandidate) {
                append = true
            }

            var bonus = 0.0
            // Consider using classNames and comparing the list
            if (topCandidate.className != "" && sibling.className == topCandidate.className) {
                bonus += topScore * 0.2
            }

            if (candidates.contains(sibling) && candidates.get(sibling).get + bonus >= siblingThreshold) {
                append = true
            }

            if (sibling.tagName == "p") {
                if (sibling.text.length > 80 && getLinkDensity(sibling) < 0.25) {
                    append = true
                } else if (sibling.text.length < 80 && getLinkDensity(sibling) == 0 && """\.( |$)""".r.findFirstIn(sibling.text) == None) {
                    append = true
                }
            }

            if (append) {

                if (sibling.tagName != "p" && sibling.tagName != "div") {
                    sibling.tagName("div")
                }

                article.appendChild(sibling)
            }
        }
    }

    private def scoreElements(elems : List[Element], shouldScoreClasses : Boolean) : scala.collection.mutable.Map[Element, Double] = {
        val scores = new scala.collection.mutable.HashMap[Element, Double]
        elems.withFilter { elem =>
            elem.parent != null && elem.text.length < 25
        }.foreach { elem =>
            val text = elem.text
            val parent = elem.parent
            val grandParent = parent.parent

            val parentScore = initialScore(parent, shouldScoreClasses)
            val grandParentScore = initialScore(grandParent, shouldScoreClasses)
            val score = 1 + elem.text.split(',').length + List(3, scala.math.floor(text.length.toFloat / 100)).min

            scores.put(parent, parentScore + score)
            scores.put(grandParent, grandParentScore + (score.toFloat / 2))
        }

        scores
    }

    private def initialScore(elem : Element, shouldScoreClasses : Boolean) : Double = {
        val initial = scoreClasses(elem, shouldScoreClasses)
        val extra = elem.tagName match {
            case "div" => 5
            case "pre" | "td" | "blockquote" => 3
            case "address" | "ol" | "ul" | "dl" | "dd" | "dt" | "li" | "form" => -3
            case "h1" | "h2" | "h3" | "h4" | "h5" | "h6" | "th" => -5
            case _ => 0
        }
        extra + initial
    }

    private def scoreClasses(elem : Element, shouldScoreClasses : Boolean) : Double = {
        var weight = 0.0
        if (shouldScoreClasses) {
            if (Readability.regexes("negative").findFirstIn(elem.className) != None) {
                weight -= 25
            }

            if (Readability.regexes("positive").findFirstIn(elem.className) != None) {
                weight += 25
            }

            if (Readability.regexes("negative").findFirstIn(elem.id) != None) {
                weight -= 25
            }

            if (Readability.regexes("positive").findFirstIn(elem.id) != None) {
                weight += 25
            }
        }
        weight
    }

    private def removeUnlikelyElements(body : Element) {
        body.getAllElements.foreach { elem =>
            val matchString = elem.className + elem.id
            lazy val unlikely = Readability.regexes("unlikely").findFirstIn(matchString) != None
            lazy val notMaybe = Readability.regexes("maybe").findFirstIn(matchString) == None
            lazy val notBody = elem.tagName != "body"
            if (unlikely && notMaybe && notBody) {
                elem.remove
            }
        }
    }

    private def getNodesToScore(body : Element) : List[Element] = {
        def filter(elem : Element) : Boolean = {
            if (Readability.regexes("scoreable").findFirstIn(elem.tagName) != None) {
                return true
            }

            if (elem.tagName == "div") {
                if (hasNoBlockLevelChildren(elem)) {
                    elem.tagName("p")
                    return true
                }
            }

            false
        }

        body.getAllElements.toList.filter(filter(_))
    }

    private def hasNoBlockLevelChildren(elem : Element) : Boolean = {
        // TODO: Refactor to use isBlock()
        elem.getAllElements.find(e => "(?i)a|blockquote|dl|div|img|ol|p|pre|table|ul".r.findFirstIn(e.tagName) == None) == None
    }

    private def extractTitle() : Element = {
        val titleElement = Readability.createElement("h1")
        extractInitialTitle match {
            case Some(title) => titleElement.html(processTitle(title))
            case _           => titleElement
        }
    }

    private def processTitle(title : String) : String = {
        // Fallback to first <h1> tag if there is only 1 <h1> tag
        """ [\|\-] """.r.findFirstIn(title) match {
            case Some(m) => {
                val processed = """(.*)[\|\-] .*""".r.replaceAllIn(title, "$1")
                if (processed.split(' ').length < 3) {
                    """[^\|\-]*[\|\-](.*)""".r.replaceAllIn(title, "$1")
                } else {
                    processed
                }
            }
            case _ => checkIndexOfColon(title)
        }
    }

    private def checkIndexOfColon(title : String) : String = {
        if (title.indexOf(": ") >= 0) {
            val processed = """.*: (.*)""".r.replaceAllIn(title, "$1")
            if (processed.split(' ').length < 3) {
                """[^:]*[:](.*)""".r.replaceAllIn(title, "$1")
            } else {
                processed
            }
        } else {
            checkTitleLength(title)
        }
    }

    private def checkTitleLength(title : String) : String = {
        if (title.length > 150 || title.length < 15) {
            val headers = doc.getElementsByTag("h1")
            if (headers.length == 1) {
                return headers.head.text
            }
        }

        title
    }

    // TODO: Possibly pull from https://github.com/peterc/pismo/blob/master/lib/pismo/internal_attributes.rb
    // Get the initial guess for a title
    private def extractInitialTitle() : Option[String] = {
        titleId.orElse(titleElement) match {
            case Some(elem) => Option(elem.text)
            case _          => None
        }
    }

    // Grab an Option[Element] of the element with id=title
    private def titleElement() : Option[Element] = {
        Option(doc.getElementById("title"))
    }

    // Grab an Option[Element] of the title element
    private def titleId() : Option[Element] = {
        doc.getElementsByTag("title").headOption
    }

    // Remove any/all tags specified
    private def removeTags(tags : String*) {
        removeTagsIf(tags:_*) { elem => true }
    }

    // Remove tags if they match a predicate function
    private def removeTagsIf(tags : String*)(pred : Element => Boolean) {
        withEachTag(tags:_*) { elem =>
            if (pred(elem)) {
                elem.remove
            }
        }
    }

    // Nicely iterate over tags
    private def withEachTag(tags : String*)(func : Element => Unit) {
        tags.foreach { tag => doc.getElementsByTag(tag).foreach(func) }
    }
}