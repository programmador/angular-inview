# #Angular-Inview
# - Author: [Nicola Peduzzi](https://github.com/thenikso)
# - Repository: https://github.com/thenikso/angular-inview
# - Install with: `bower install angular-inview`
# - Version: **1.5.0**

'use strict'

# An [angular.js](https://angularjs.org) directive to evaluate an expression if
# a DOM element is or not in the current visible browser viewport.
# Use it in your Angular.js app by including the javascript and requireing it:
#
# `angular.module('myApp', ['angular-inview'])`
angularInviewModule = angular.module('angular-inview', [])

	# ##in-view directive
	#
	# **Usage**
	# ```html
	# <any in-view="{expression}" [in-view-options="{object}"]></any>
	# ```
	.directive 'inView', ['$parse', ($parse) ->
		# Evaluate the expression passet to the attribute `in-view` when the DOM
		# element is visible in the viewport.
		restrict: 'A'
		# If the `in-view` element is contained in a scrollable view other than the
		# window, that containing element should be [marked as a container](#in-view-container-directive).
		require: '?^inViewContainer'
		link: (scope, element, attrs, containerController) ->
			return unless attrs.inView
			inViewFunc = $parse(attrs.inView)
			item =
				element: element
				wasInViewVertical: no
				wasInViewHorizontal: no
				offset: 0
				customDebouncedCheck: null
				# In the callback expression, the following variables will be provided:
				# - `$event`: the DOM event that triggered the inView callback.
				# The inView DOM element will be passed in `$event.inViewTarget`.
				# - `$inview`: boolean indicating if the element is in view
				# - `$inviewpartVertical`: string either 'top', 'bottom' or 'both'
				# - `inviewpartHorizontal`: string either 'left', 'right' or 'both'
				callback: ($event={}, $inview, $inviewpartVertical, $inviewpartHorizontal) -> scope.$evalAsync =>
					$event.inViewTarget = element[0]
					inViewFunc scope,
						'$event': $event
						'$inview': $inview
						'$inviewpartVertical': $inviewpartVertical
						'$inviewpartHorizontal': $inviewpartHorizontal
			# An additional `in-view-options` attribute can be specified to set offsets
			# that will displace the inView calculation and a debounce to slow down updates
			# via scrolling events.
			if attrs.inViewOptions? and options = scope.$eval(attrs.inViewOptions)
				item.offset = options.offset || [
					options.offsetTop or 0,
					options.offsetBottom or 0,
					options.offsetLeft or 0,
					options.offsetRight or 0
				]
				if options.debounce
					item.customDebouncedCheck = debounce ((event) -> checkInView [item], element[0], event), options.debounce
			# A series of checks are set up to verify the status of the element visibility.
			performCheck = item.customDebouncedCheck ? containerController?.checkInView ? windowCheckInView
			if containerController?
				containerController.addItem item
			else
				addWindowInViewItem item
			# This checks will be performed immediatly and when a relevant measure changes.
			setTimeout performCheck
			# When the element is removed, all the logic behind in-view is removed.
			# One might want to use `in-view` in conjunction with `ng-if` when using
			# the directive for lazy loading.
			scope.$on '$destroy', ->
				containerController?.removeItem item
				removeWindowInViewItem item
	]

	# ## in-view-container directive
	.directive 'inViewContainer', ->
		# Use this as an attribute or a class to mark a scrollable container holding
		# `in-view` directives as children.
		restrict: 'AC'
		# This directive will track child `in-view` elements.
		controller: ['$element', ($element) ->
			@items = []
			@addItem = (item) ->
				@items.push item
			@removeItem = (item) ->
				@items = (i for i in @items when i isnt item)
			@checkInView = (event) =>
				i.customDebouncedCheck() for i in @items when i.customDebouncedCheck?
				checkInView (i for i in @items when not i.customDebouncedCheck?), $element[0], event
			@
		]
		# Custom checks on child `in-view` elements will be triggered when the
		# `in-view-container` scrolls.
		link: (scope, element, attrs, controller) ->
			element.bind 'scroll', controller.checkInView
			trackInViewContainer controller
			scope.$on '$destroy', ->
				element.unbind 'scroll', controller.checkInView
				untrackInViewContainer controller

# ## Utilities

# ### items management

# The collectin of all in-view items. Items are object with the structure:
# ```
# {
# 	element: <angular.element>,
# 	offset: <number>,
# 	wasInViewVertical: <bool>,
# 	wasInViewHorizontal: <bool>,
# 	callback: <funciton>
# }
# ```
_windowInViewItems = []
addWindowInViewItem = (item) ->
	_windowInViewItems.push item
	do bindWindowEvents
removeWindowInViewItem = (item) ->
	_windowInViewItems = (i for i in _windowInViewItems when i isnt item)
	do unbindWindowEvents

# List of containers controllers
_containersControllers = []
trackInViewContainer = (controller) ->
	_containersControllers.push controller
	do bindWindowEvents
untrackInViewContainer = (container) ->
	_containersControllers = (c for c in _containersControllers when c isnt container)
	do unbindWindowEvents

# ### Events handler management
_windowEventsHandlerBinded = no
windowEventsHandler = (event) ->
	c.checkInView(event) for c in _containersControllers
	windowCheckInView(event) if _windowInViewItems.length
bindWindowEvents = ->
	# The bind to window events will be added only if actually needed.
	return if _windowEventsHandlerBinded
	_windowEventsHandlerBinded = yes
	angular.element(window).bind 'checkInView click ready wheel mousewheel DomMouseScroll MozMousePixelScroll resize scroll touchmove mouseup', windowEventsHandler
unbindWindowEvents = ->
	# All the window bindings will be removed if no directive requires to be checked.
	return unless _windowEventsHandlerBinded
	return if _windowInViewItems.length or _containersControllers.length
	_windowEventsHandlerBinded = no
	angular.element(window).unbind 'checkInView click ready wheel mousewheel DomMouseScroll MozMousePixelScroll resize scroll touchmove mouseup', windowEventsHandler

# ### InView checks
# This method will call the user defined callback with the proper parameters if neccessary.
triggerInViewCallback = (event, item, inview, isTopVisible, isBottomVisible, isLeftVisible, isRightVisible) ->
	if inview
		elOffsetTop = getBoundingClientRect(item.element[0]).top + window.pageYOffset
		elOffsetLeft = getBoundingClientRect(item.element[0]).left + window.pageXOffset
		inviewpartVertical = (isTopVisible and isBottomVisible and 'neither') or (isTopVisible and 'top') or (isBottomVisible and 'bottom') or 'both'
		inviewpartHorizontal = (isLeftVisible and isRightVisible and 'neither') or (isLeftVisible and 'left') or (isRightVisible and 'right') or 'both'
		# The callback will be called only if a relevant value has changed.
		# However, if the element changed it's position (for example if it has been
		# pushed down by dynamically loaded content), the callback will be called anyway.
		unless item.wasInViewVertical and
			item.wasInViewVertical == inviewpartVertical and
			item.wasInViewHorizontal == inviewpartHorizontal and
			elOffsetTop == item.lastOffsetTop
				item.lastOffsetTop = elOffsetTop
				item.wasInViewVertical = inviewpartVertical
				item.wasInViewHorizontal = inviewpartHorizontal
				item.callback event, yes, inviewpartVertical, inviewpartHorizontal
	else if item.wasInViewVertical or inviewpartHorizontal
		item.wasInViewVertical = no
		item.inviewpartHorizontal = no
		item.callback event, no, no

# The main function to check if the given items are in view relative to the provided container.
checkInView = (items, container, event) ->
	# It first calculate the viewport.
	viewport =
		top: 0
		bottom: getViewportHeight()
		left: 0
		right: getViewportWidth()
	# Restrict viewport if a container is specified.
	if container and container isnt window
		bounds = getBoundingClientRect container
		# Shortcut to all item not in view if container isn't itself.
		if bounds.top > viewport.bottom or bounds.bottom < viewport.top
			triggerInViewCallback(event, item, false) for item in items
			return
		if bounds.left > viewport.right or bounds.right < viewport.left
			triggerInViewCallback(event, item, false) for item in items
			return
		# Actual viewport restriction.
		viewport.top = bounds.top if bounds.top > viewport.top
		viewport.bottom = bounds.bottom if bounds.bottom < viewport.bottom
		viewport.left = bounds.left if bounds.left > viewport.left
		viewport.right = bounds.right if bounds.right < viewport.right
	# Calculate inview status for each item.
	for item in items
		# Get the bounding top and bottom of the element in the viewport.
		element = item.element[0]
		bounds = getBoundingClientRect element
		# Apply offset.
		boundsTop = bounds.top + if offsetIsPercentage(item.offset) then getOffsetFromPercentage(bounds, item.offset, false) else parseInt(item.offset?[0] ? item.offset)
		boundsBottom = bounds.bottom + if offsetIsPercentage(item.offset) then getOffsetFromPercentage(bounds, item.offset, false) else parseInt(item.offset?[1] ? item.offset)
		boundsLeft = bounds.left + if offsetIsPercentage(item.offset) then getOffsetFromPercentage(bounds, item.offset, true) else parseInt(item.offset?[2] ? item.offset)
		boundsRight = bounds.right + if offsetIsPercentage(item.offset) then getOffsetFromPercentage(bounds, item.offset, true) else parseInt(item.offset?[3] ? item.offset)
		# Calculate parts in view.
		if boundsTop < viewport.bottom and boundsBottom >= viewport.top and boundsLeft < viewport.right and boundsRight >= viewport.left
			triggerInViewCallback(event, item, true, boundsBottom > viewport.bottom, boundsTop < viewport.top, boundsRight > viewport.right, boundsLeft < viewport.left)
		else
			triggerInViewCallback(event, item, false)

# ### Utility functions

# Checks if the provided offset value is a percentage or not
offsetIsPercentage = (offset) ->
	typeof offset is 'string' and offset.slice(-1) is '%'

# Calculates the offset in pixels based on the percentage provided
getOffsetFromPercentage = (bounds, offsetPercentage, horizontal) ->
	settings = offsetPercentage.split(' ');
	if settings.length == 1
		settings[1] = '0%';
	percentageVertical = settings[0].substring 0, settings[0].length - 1
	percentageHorizontal = settings[1].substring 0, settings[1].length - 1
	if horizontal
		return (bounds.bottom - bounds.top) * (percentageVertical / 100)
	else
		return (bounds.right - bounds.left) * (percentageHorizontal / 100)

# Returns the height of the window viewport
getViewportHeight = ->
	height = window.innerHeight
	return height if height
	mode = document.compatMode
	if mode or not $?.support?.boxModel
		height = if mode is 'CSS1Compat' then document.documentElement.clientHeight else document.body.clientHeight
	height

# Returns the width of the window viewport
getViewportWidth = ->
	width = window.innerWidth
	return width if width
	mode = document.compatMode
	if mode or not $?.support?.boxModel
		width = if mode is 'CSS1Compat' then document.documentElement.clientWidth else document.body.clientWidth
	width

# Polyfill for `getBoundingClientRect`
getBoundingClientRect = (element) ->
	return element.getBoundingClientRect() if element.getBoundingClientRect?
	top = 0
	left = 0
	el = element
	while el
		top += el.offsetTop
		left += el.offsetLeft
		el = el.offsetParent
	parent = element.parentElement
	while parent
		top -= parent.scrollTop if parent.scrollTop?
		left -= parent.scrollLeft if parent.scrollLeft?
		parent = parent.parentElement
	return {
		top: top
		bottom: top + element.offsetHeight
		left: left
		right: left + element.offsetWidth
	}

# Debounce a function.
debounce = (f, t) ->
	timer = null
	(args...)->
		clearTimeout timer if timer?
		timer = setTimeout (-> f(args...)), (t ? 100)

# The main function to perform in-view checks on all items.
windowCheckInView = (event) ->
	i.customDebouncedCheck() for i in _windowInViewItems when i.customDebouncedCheck?
	checkInView (i for i in _windowInViewItems when not i.customDebouncedCheck?), null, event

if typeof define is 'function' && define.amd
	define(['angular'], angularInviewModule)
else if typeof module isnt 'undefined' && module && module.exports
	module.exports = angularInviewModule
