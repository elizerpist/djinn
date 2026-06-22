package com.elizerpist.djinn.rail

import android.app.Activity
import android.graphics.Color
import android.graphics.Rect
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowInsetsAnimation
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.max

class NativeSelectionRailBridge(
    private val activity: Activity,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, SelectionRailChannels.METHOD)
    private val decorRoot: ViewGroup? = activity.window.decorView as? ViewGroup
    private val visibleFrame = Rect()
    private val railContainer = FrameLayout(activity)
    private val railContent = LinearLayout(activity)
    private val actionRow = LinearLayout(activity)
    private val tagScroll = HorizontalScrollView(activity)
    private val tagRow = LinearLayout(activity)

    private var currentState: RailState = RailState.hidden()
    private var attached = false
    private var lastImeBottom = 0

    init {
        channel.setMethodCallHandler(this)
        configureRailView()
        attachRailView()
        installInsetsCallbacks()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setState" -> {
                val state = RailState.from(call.arguments)
                currentState = state
                renderState(state)
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun configureRailView() {
        railContainer.visibility = View.GONE
        railContainer.isClickable = true
        railContainer.elevation = 0f
        railContainer.setPadding(0, 0, 0, 0)

        railContent.orientation = LinearLayout.VERTICAL
        railContent.setPadding(dp(10), dp(8), dp(10), dp(8))

        actionRow.orientation = LinearLayout.HORIZONTAL
        actionRow.gravity = Gravity.CENTER_VERTICAL

        tagScroll.isHorizontalScrollBarEnabled = false
        tagRow.orientation = LinearLayout.HORIZONTAL
        tagRow.gravity = Gravity.CENTER_VERTICAL
        tagScroll.addView(
            tagRow,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        )

        railContent.addView(
            actionRow,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        )
        railContent.addView(
            tagScroll,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = dp(6)
            }
        )
        railContainer.addView(
            railContent,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        )
        renderState(currentState)
    }

    private fun attachRailView() {
        val root = decorRoot ?: return
        if (attached) {
            return
        }
        root.addView(
            railContainer,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM
            )
        )
        attached = true
        railContainer.requestApplyInsets()
    }

    private fun installInsetsCallbacks() {
        val root = decorRoot ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            root.setWindowInsetsAnimationCallback(
                object : WindowInsetsAnimation.Callback(
                    WindowInsetsAnimation.Callback.DISPATCH_MODE_CONTINUE_ON_SUBTREE
                ) {
                    override fun onProgress(
                        insets: WindowInsets,
                        runningAnimations: MutableList<WindowInsetsAnimation>
                    ): WindowInsets {
                        positionRail(insets.getInsets(WindowInsets.Type.ime()).bottom)
                        return insets
                    }
                }
            )
        }
        railContainer.setOnApplyWindowInsetsListener { _, insets ->
            positionRail(imeBottom(insets))
            insets
        }
        root.viewTreeObserver.addOnGlobalLayoutListener {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
                positionRail(estimatedKeyboardBottom())
            }
        }
    }

    private fun imeBottom(insets: WindowInsets): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            insets.getInsets(WindowInsets.Type.ime()).bottom
        } else {
            @Suppress("DEPRECATION")
            insets.systemWindowInsetBottom
        }
    }

    private fun estimatedKeyboardBottom(): Int {
        val root = decorRoot ?: return 0
        root.getWindowVisibleDisplayFrame(visibleFrame)
        return max(0, root.rootView.height - visibleFrame.bottom)
    }

    private fun positionRail(imeBottom: Int) {
        lastImeBottom = max(0, imeBottom)
        railContainer.translationY = -lastImeBottom.toFloat()
    }

    private fun renderState(state: RailState) {
        railContainer.visibility = if (state.visible) View.VISIBLE else View.GONE
        if (!state.visible) {
            return
        }
        railContent.background = railBackground(state)
        renderActions(state)
        renderTags(state)
        positionRail(max(lastImeBottom, estimatedKeyboardBottom()))
    }

    private fun renderActions(state: RailState) {
        actionRow.removeAllViews()
        actionRow.addView(
            actionButton(
                "toggleTags",
                if (state.bottomRowExpanded) "^" else "v",
                state.actionEnabled("toggleTags")
            )
        )
        actionRow.addView(actionButton("outdent", "<", state.actionEnabled("outdent")))
        actionRow.addView(actionButton("indent", ">", state.actionEnabled("indent")))
        actionRow.addView(actionButton("tagSelection", "Tag", state.actionEnabled("tagSelection")))
        actionRow.addView(actionButton("clearTags", "Del", state.actionEnabled("clearTags")))
        actionRow.addView(actionButton("previousTag", "Prev", state.actionEnabled("previousTag")))
        actionRow.addView(actionButton("nextTag", "Next", state.actionEnabled("nextTag")))
        actionRow.addView(actionButton("toggleRounded", "R", state.actionEnabled("toggleRounded")))
        actionRow.addView(actionButton("toggleGrey", "G", state.actionEnabled("toggleGrey")))
        actionRow.addView(actionButton("toggleBorder", "B", state.actionEnabled("toggleBorder")))
    }

    private fun renderTags(state: RailState) {
        tagRow.removeAllViews()
        tagScroll.visibility = if (state.bottomRowExpanded && state.tags.isNotEmpty()) {
            View.VISIBLE
        } else {
            View.GONE
        }
        for (tag in state.tags) {
            tagRow.addView(tagPill(tag))
        }
    }

    private fun actionButton(action: String, label: String, enabled: Boolean): TextView {
        return TextView(activity).apply {
            text = label
            textSize = 13f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            isEnabled = enabled
            isClickable = enabled
            alpha = if (enabled) 1f else 0.35f
            setTextColor(Color.rgb(17, 24, 39))
            setPadding(dp(10), 0, dp(10), 0)
            minWidth = dp(40)
            minHeight = dp(34)
            background = buttonBackground()
            setOnClickListener {
                invokeAction(action)
            }
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                dp(34)
            ).apply {
                rightMargin = dp(6)
            }
        }
    }

    private fun tagPill(tag: RailTag): TextView {
        val color = tag.colorValue ?: Color.rgb(37, 99, 235)
        return TextView(activity).apply {
            text = tag.label
            textSize = 13f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setTextColor(color)
            setPadding(dp(12), 0, dp(12), 0)
            minHeight = dp(30)
            background = pillBackground(color)
            setOnClickListener {
                invokeAction("deleteTag", tag.id)
            }
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                dp(30)
            ).apply {
                rightMargin = dp(6)
            }
        }
    }

    private fun invokeAction(action: String, tagId: String? = null) {
        val payload = mutableMapOf<String, Any>("action" to action)
        if (tagId != null) {
            payload["tagId"] = tagId
        }
        channel.invokeMethod("performAction", payload)
    }

    private fun railBackground(state: RailState): GradientDrawable {
        val backgroundColor = if (state.greyBackground) {
            Color.rgb(248, 250, 252)
        } else {
            Color.WHITE
        }
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = if (state.roundedCard) dp(8).toFloat() else 0f
            setColor(backgroundColor)
            if (state.borderVisible) {
                setStroke(dp(1), Color.rgb(209, 213, 219))
            }
        }
    }

    private fun buttonBackground(): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(7).toFloat()
            setColor(Color.rgb(249, 250, 251))
            setStroke(dp(1), Color.rgb(229, 231, 235))
        }
    }

    private fun pillBackground(color: Int): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(15).toFloat()
            setColor(adjustAlpha(color, 0.12f))
            setStroke(dp(1), adjustAlpha(color, 0.28f))
        }
    }

    private fun adjustAlpha(color: Int, factor: Float): Int {
        return Color.argb(
            (Color.alpha(color) * factor).toInt().coerceIn(0, 255),
            Color.red(color),
            Color.green(color),
            Color.blue(color)
        )
    }

    private fun dp(value: Int): Int {
        return (value * activity.resources.displayMetrics.density).toInt()
    }
}

private data class RailState(
    val visible: Boolean,
    val tags: List<RailTag>,
    val actions: Map<String, Boolean>,
    val bottomRowExpanded: Boolean,
    val roundedCard: Boolean,
    val greyBackground: Boolean,
    val borderVisible: Boolean
) {
    fun actionEnabled(action: String): Boolean = actions[action] ?: false

    companion object {
        fun hidden(): RailState {
            return RailState(
                visible = false,
                tags = emptyList(),
                actions = emptyMap(),
                bottomRowExpanded = true,
                roundedCard = false,
                greyBackground = false,
                borderVisible = true
            )
        }

        fun from(value: Any?): RailState {
            val map = value as? Map<*, *> ?: return hidden()
            val visible = map["visible"] as? Boolean ?: false
            if (!visible) {
                return hidden()
            }
            val style = map["style"] as? Map<*, *> ?: emptyMap<Any, Any>()
            val actions = (map["actions"] as? Map<*, *>)
                ?.mapNotNull { entry ->
                    val key = entry.key as? String ?: return@mapNotNull null
                    key to (entry.value as? Boolean ?: false)
                }
                ?.toMap()
                ?: emptyMap()
            return RailState(
                visible = true,
                tags = RailTag.listFrom(map["tags"]),
                actions = actions,
                bottomRowExpanded = style["bottomRowExpanded"] as? Boolean ?: true,
                roundedCard = style["roundedCard"] as? Boolean ?: false,
                greyBackground = style["greyBackground"] as? Boolean ?: false,
                borderVisible = style["borderVisible"] as? Boolean ?: true
            )
        }
    }
}

private data class RailTag(
    val id: String,
    val label: String,
    val colorValue: Int?
) {
    companion object {
        fun listFrom(value: Any?): List<RailTag> {
            val rawTags = value as? List<*> ?: return emptyList()
            return rawTags.mapNotNull { raw ->
                val map = raw as? Map<*, *> ?: return@mapNotNull null
                val id = map["id"] as? String ?: return@mapNotNull null
                val label = map["label"] as? String ?: id
                val colorNumber = map["colorValue"] as? Number
                RailTag(id = id, label = label, colorValue = colorNumber?.toInt())
            }
        }
    }
}
