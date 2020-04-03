//
//  StackTransformView.swift
//  CollectionViewPagingLayout
//
//  Created by Amir on 21/02/2020.
//  Copyright © 2020 Amir Khorsandi. All rights reserved.
//

import UIKit

/// A protocol for adding stack transformation effect to `TransformableView`
public protocol StackTransformView: TransformableView {
    
    /// Options for controlling stack effects, see `StackTransformViewOptions.swift`
    var options: StackTransformViewOptions { get }
    
    /// The view to apply scale effect on
    var cardView: UIView { get }
    
    /// The view to apply blur effect on
    var blurViewHost: UIView { get }
}


public extension StackTransformView {
    
    /// The default value is the super view of `cardView`
    var blurViewHost: UIView {
        cardView.superview ?? cardView
    }
    
}


public extension StackTransformView where Self: UICollectionViewCell {
    
    /// Default `cardView` for `UICollectionViewCell` is the first subview of
    /// `contentView` or the content view itself in case of no subviews
    var cardView: UIView {
        contentView.subviews.first ?? contentView
    }
}


public extension StackTransformView {
    
    // MARK: Properties
    
    var options: StackTransformViewOptions {
        .init()
    }
    
    
    // MARK: TransformableView
    
    func transform(progress: CGFloat) {
        applyStackTransform(progress: progress)
    }
    
    func zPosition(progress: CGFloat) -> Int {
        var zPosition = -Int(round(progress))
        if options.reverse {
            zPosition *= -1
        }
        return zPosition
    }
    
    
    // MARK: Public functions
    
    func applyStackTransform(progress: CGFloat) {
        var progress = progress
        if options.reverse {
            progress *= -1
        }
        applyStyle(progress: progress)
        applyScale(progress: progress)
        applyAlpha(progress: progress)
        applyRotation(progress: progress)
        if #available(iOS 10, *) {
            applyBlurEffect(progress: progress)
        }
    }
    
    
    // MARK: Private functions
    
    private func applyStyle(progress: CGFloat) {
        guard options.shadowEnabled else {
            return
        }
        let layer = cardView.layer
        layer.shadowColor = options.shadowColor.cgColor
        layer.shadowOffset = options.shadowOffset
        layer.shadowRadius = options.shadowRadius
        layer.shadowOpacity = options.shadowOpacity
    }
    
    private func applyScale(progress: CGFloat) {
        var transform = CGAffineTransform.identity
        var xAdjustment: CGFloat = 0
        var yAdjustment: CGFloat = 0
        
        var scale = 1 - progress * options.scaleFactor
        if let minScale = options.minScale {
            scale = max(minScale, scale)
        }
        if let maxScale = options.maxScale {
            scale = min(maxScale, scale)
        }
        
        let stackProgress = progress.interpolate(in: .init(0, CGFloat(options.maxStackSize)))
        let perspectiveProgress  = TransformCurve.easeOut.computeFromLinear(progress: stackProgress) * options.perspectiveRatio
        
    
        var xSpacing = cardView.bounds.width * options.spacingFactor
        if let max = options.maxSpacing {
            xSpacing = min(xSpacing, cardView.bounds.width * max)
        }
        let translateX = xSpacing * -max(progress, 0) * -options.stackPosition.x
        
        var ySpacing = cardView.bounds.height * options.spacingFactor
        if let max = options.maxSpacing {
            ySpacing = min(ySpacing, cardView.bounds.height * max)
        }
        let translateY = ySpacing * -max(progress, 0) * -options.stackPosition.y
        
        yAdjustment = ((scale - 1) * cardView.bounds.height) / 2 // make y equal for all cards
        yAdjustment += perspectiveProgress * cardView.bounds.height
        yAdjustment *= -options.stackPosition.y
        
        xAdjustment = ((scale - 1) * cardView.bounds.width) / 2 // make x equal for all cards
        xAdjustment += perspectiveProgress * cardView.bounds.width
        xAdjustment *= -options.stackPosition.x
        
        
        if progress < 0 {
            xAdjustment -= cardView.bounds.width * options.popOffsetRatio.width * progress
            yAdjustment -= cardView.bounds.height * options.popOffsetRatio.height * progress
        }
        
        transform = transform
            .translatedBy(x: translateX + xAdjustment, y: translateY + yAdjustment)
            .scaledBy(x: scale, y: scale)
        cardView.transform = transform
    }
    
    private func applyAlpha(progress: CGFloat) {
        cardView.alpha = 1
        
        let floatStackSize = CGFloat(options.maxStackSize)
        if progress >= floatStackSize - 1 {
            let targetCard = floatStackSize - 1
            cardView.alpha = 1 - progress.interpolate(
                in: .init(targetCard, targetCard + options.bottomStackAlphaSpeedFactor)
            )
        } else if progress < 0 {
            cardView.alpha = progress.interpolate(in: .init(-1, -1 + options.topStackAlphaSpeedFactor))
        }
        
        if cardView.alpha > 0, progress >= 0 {
            cardView.alpha -= progress * options.alphaFactor
        }
        
    }
    
    private func applyRotation(progress: CGFloat) {
        var angle: CGFloat = 0
        if progress <= 0 {
            angle = -abs(progress).interpolate(out: .init(0, abs(options.popAngle)))
            if options.popAngle < 0 {
                angle *= -1
            }
        } else {
            let floatAmount = abs(progress - CGFloat(Int(progress)))
            angle = -floatAmount * options.stackRotateAngel * 2 + options.stackRotateAngel
            if Int(progress) % 2 == 0 {
                angle *= -1
            }
            if progress < 1 {
                angle += (1 - progress).interpolate(out: .init(0, options.stackRotateAngel))
            }
        }
        
        cardView.transform = cardView.transform.rotated(by: angle)
    }
    
    @available(iOS 10.0, *)
    private func applyBlurEffect(progress: CGFloat) {
        guard options.maxBlurEffectRadius > 0, options.blurEffectEnabled else {
            return
        }
        let blurView: BlurEffectView
        if let view = blurViewHost.subviews.first(where: { $0 is BlurEffectView }) as? BlurEffectView {
            blurView = view
        } else {
            blurView = BlurEffectView()
            blurViewHost.fill(with: blurView)
        }
        let radius = max(progress, 0).interpolate(in: .init(0, CGFloat(options.maxStackSize)))
        blurView.setBlurRadius(effect: UIBlurEffect(style: options.blurEffectStyle), radius: radius * options.maxBlurEffectRadius)
    }
    
}
