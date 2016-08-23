import UIKit

func addTransformAnimation(animation: Animatable, sceneLayer: CALayer, animationCache: AnimationCache, completion: (() -> ())) {
	guard let transformAnimation = animation as? TransformAnimation else {
		return
	}

	guard let node = animation.node else {
		return
	}

	var offset = Point.origin
	if let shapeBounds = node.bounds() {
		offset = Point(x: shapeBounds.x, y: shapeBounds.y)
	}

	// Creating proper animation
	var generatedAnimation: CAAnimation?

	generatedAnimation = transformAnimationByFunc(transformAnimation.vFunc, duration: animation.getDuration(), offset: offset, fps: transformAnimation.logicalFps)

	guard let generatedAnim = generatedAnimation else {
		return
	}

	generatedAnim.autoreverses = animation.autoreverses
	generatedAnim.repeatCount = Float(animation.repeatCount)
	generatedAnim.timingFunction = caTimingFunction(animation.timingFunction)

	generatedAnim.completion = { finished in

		animation.progress = 1.0
		node.posVar.value = transformAnimation.vFunc(1.0)

		animationCache.freeLayer(node)
		animation.completion?()
		completion()
	}

	generatedAnim.progress = { progress in

		let t = Double(progress)
		node.posVar.value = transformAnimation.vFunc(t)

		animation.progress = t
		animation.onProgressUpdate?(t)

	}

	let layer = animationCache.layerForNode(node, animation: animation)

	layer.addAnimation(generatedAnim, forKey: animation.ID)
	animation.removeFunc = {
		layer.removeAnimationForKey(animation.ID)
	}
}

func transfomToCG(transform: Transform) -> CGAffineTransform {
	return CGAffineTransformMake(
		CGFloat(transform.m11),
		CGFloat(transform.m12),
		CGFloat(transform.m21),
		CGFloat(transform.m22),
		CGFloat(transform.dx),
		CGFloat(transform.dy))
}

func transformAnimationByFunc(valueFunc: (Double) -> Transform, duration: Double, offset: Point, fps: UInt) -> CAAnimation {

	var scaleXValues = [CGFloat]()
	var scaleYValues = [CGFloat]()
	var xValues = [CGFloat]()
	var yValues = [CGFloat]()
	var rotationValues = [CGFloat]()
	var timeValues = [Double]()

	let rect = CGRectMake(0.0, 0.0, 1.0, 1.0)

	let step = 1.0 / (duration * Double(fps))
	for t in 0.0.stride(to: 1.0, by: step) {

		let value = valueFunc(t)
		let cgTransform = transfomToCG(value)
		let transformedRect = CGRectApplyAffineTransform(rect, cgTransform)

		timeValues.append(t)
		xValues.append(transformedRect.origin.x + CGFloat(offset.x))
		yValues.append(transformedRect.origin.y + CGFloat(offset.y))
		scaleXValues.append(transformedRect.width)
		scaleYValues.append(transformedRect.height)

		let angle = atan2(cgTransform.b, cgTransform.a)
		rotationValues.append(fixedAngle(angle))
	}

	let xAnimation = CAKeyframeAnimation(keyPath: "transform.translation.x")
	xAnimation.duration = duration
	xAnimation.values = xValues
	xAnimation.keyTimes = timeValues

	let yAnimation = CAKeyframeAnimation(keyPath: "transform.translation.y")
	yAnimation.duration = duration
	yAnimation.values = yValues
	yAnimation.keyTimes = timeValues

	let scaleXAnimation = CAKeyframeAnimation(keyPath: "transform.scale.x")
	scaleXAnimation.duration = duration
	scaleXAnimation.values = scaleXValues
	scaleXAnimation.keyTimes = timeValues

	let scaleYAnimation = CAKeyframeAnimation(keyPath: "transform.scale.y")
	scaleYAnimation.duration = duration
	scaleYAnimation.values = scaleYValues
	scaleYAnimation.keyTimes = timeValues

	let rotationAnimation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
	rotationAnimation.duration = duration
	rotationAnimation.values = rotationValues
	rotationAnimation.keyTimes = timeValues

	let group = CAAnimationGroup()
	group.fillMode = kCAFillModeForwards
	group.removedOnCompletion = false

	group.animations = [xAnimation, yAnimation, scaleXAnimation, scaleYAnimation, rotationAnimation]
	group.duration = duration

	return group
}

func fixedAngle(angle: CGFloat) -> CGFloat {
	return angle > -0.0000000000000000000000001 ? angle : CGFloat(2.0 * M_PI) + angle
}
