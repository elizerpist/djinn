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
    private val actionScroll = HorizontalScrollView(activity)
    private val actionRow = LinearLayout(activity)
    private val rowDivider = View(activity)
    private val tagScroll = HorizontalScrollView(activity)
    private val tagRow = LinearLayout(activity)
    private val materialIconTypeface: Typeface? by lazy {
        runCatching {
            Typeface.createFromAsset(
                activity.assets,
                "flutter_assets/fonts/MaterialIcons-Regular.otf"
            )
        }.getOrNull()
    }

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
        railContent.setPadding(0, 0, 0, 0)

        actionScroll.isHorizontalScrollBarEnabled = false
        actionScroll.overScrollMode = View.OVER_SCROLL_NEVER
        actionRow.orientation = LinearLayout.HORIZONTAL
        actionRow.gravity = Gravity.CENTER_VERTICAL
        actionRow.setPadding(dp(10), dp(8), dp(6), dp(8))
        actionScroll.addView(
            actionRow,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )

        rowDivider.setBackgroundColor(Color.rgb(229, 231, 235))
        tagScroll.isHorizontalScrollBarEnabled = false
        tagScroll.overScrollMode = View.OVER_SCROLL_NEVER
        tagRow.orientation = LinearLayout.HORIZONTAL
        tagRow.gravity = Gravity.CENTER_VERTICAL
        tagRow.setPadding(dp(10), dp(7), dp(6), dp(7))
        tagScroll.addView(
            tagRow,
            ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )

        railContent.addView(
            actionScroll,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(64)
            )
        )
        railContent.addView(
            rowDivider,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(1)
            )
        )
        railContent.addView(
            tagScroll,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(48)
            )
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
                if (state.bottomRowExpanded) ICON_KEYBOARD_ARROW_UP else ICON_KEYBOARD_ARROW_DOWN,
                state.actionEnabled("toggleTags")
            )
        )
        actionRow.addView(actionButton("outdent", ICON_FORMAT_INDENT_DECREASE, state.actionEnabled("outdent")))
        actionRow.addView(actionButton("indent", ICON_FORMAT_INDENT_INCREASE, state.actionEnabled("indent")))
        actionRow.addView(actionButton("tagSelection", ICON_SELL_OUTLINED, state.actionEnabled("tagSelection")))
        actionRow.addView(actionButton("clearTags", ICON_DELETE_OUTLINE, state.actionEnabled("clearTags")))
        actionRow.addView(actionButton("previousTag", ICON_CHEVRON_LEFT, state.actionEnabled("previousTag")))
        actionRow.addView(actionButton("nextTag", ICON_CHEVRON_RIGHT, state.actionEnabled("nextTag")))
        actionRow.addView(actionButton("toggleRounded", ICON_CROP_SQUARE_OUTLINED, state.actionEnabled("toggleRounded")))
        actionRow.addView(actionButton("toggleGrey", ICON_OPACITY, state.actionEnabled("toggleGrey")))
        actionRow.addView(actionButton("toggleBorder", ICON_BORDER_OUTER, state.actionEnabled("toggleBorder")))
    }

    private fun renderTags(state: RailState) {
        tagRow.removeAllViews()
        rowDivider.visibility = if (state.bottomRowExpanded) View.VISIBLE else View.GONE
        tagScroll.visibility = if (state.bottomRowExpanded) View.VISIBLE else View.GONE
        if (!state.bottomRowExpanded) {
            return
        }
        if (state.tags.isEmpty()) {
            tagRow.addView(emptyTagLabel())
            return
        }
        for (tag in state.tags) {
            tagRow.addView(tagPill(tag))
        }
    }

    private fun actionButton(action: String, iconCodePoint: Int, enabled: Boolean): TextView {
        return TextView(activity).apply {
            text = String(Character.toChars(iconCodePoint))
            textSize = 20f
            typeface = materialIconTypeface ?: Typeface.DEFAULT
            gravity = Gravity.CENTER
            isEnabled = enabled
            isClickable = enabled
            alpha = if (enabled) 1f else 0.35f
            setTextColor(Color.rgb(17, 24, 39))
            includeFontPadding = false
            setPadding(0, 0, 0, 0)
            minWidth = dp(34)
            minHeight = dp(34)
            setOnClickListener {
                invokeAction(action)
            }
            layoutParams = LinearLayout.LayoutParams(
                dp(34),
                dp(34)
            ).apply {
                rightMargin = dp(4)
            }
        }
    }

    private fun tagPill(tag: RailTag): TextView {
        val color = tag.colorValue ?: Color.rgb(37, 99, 235)
        return TextView(activity).apply {
            text = tag.label
            textSize = 12f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            includeFontPadding = false
            setPadding(dp(9), 0, dp(9), 0)
            minHeight = dp(28)
            background = pillBackground(color)
            setOnClickListener {
                invokeAction("deleteTag", tag.id)
            }
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                dp(28)
            ).apply {
                rightMargin = dp(8)
            }
        }
    }

    private fun emptyTagLabel(): TextView {
        return TextView(activity).apply {
            text = "Nincs tag"
            textSize = 12f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER_VERTICAL
            setTextColor(Color.rgb(107, 114, 128))
            includeFontPadding = false
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
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

    private fun pillBackground(color: Int): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(999).toFloat()
            setColor(color)
        }
    }

    private fun dp(value: Int): Int {
        return (value * activity.resources.displayMetrics.density).toInt()
    }

    private companion object {
        private const val ICON_BORDER_OUTER = 0xe0fe
        private const val ICON_CHEVRON_LEFT = 0xe15e
        private const val ICON_CHEVRON_RIGHT = 0xe15f
        private const val ICON_CROP_SQUARE_OUTLINED = 0xef9d
        private const val ICON_DELETE_OUTLINE = 0xe1bb
        private const val ICON_FORMAT_INDENT_DECREASE = 0xe2b4
        private const val ICON_FORMAT_INDENT_INCREASE = 0xe2b5
        private const val ICON_KEYBOARD_ARROW_DOWN = 0xe353
        private const val ICON_KEYBOARD_ARROW_UP = 0xe356
        private const val ICON_OPACITY = 0xe459
        private const val ICON_SELL_OUTLINED = 0xf353
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
