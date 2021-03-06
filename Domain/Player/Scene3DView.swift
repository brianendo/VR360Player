//
//  Scene3DView.swift
//  VR360Player
//
//  Created by Brian Endo on 6/23/16.
//  Copyright © 2016 Brian Endo. All rights reserved.
//


import GLKit

class Scene3DView: GLKView
{
    private var sceneObjects = [NSObject]()

    // MARK: - Properties
    var camera = Camera()
    {
        didSet { self.setNeedsDisplay() }
    }

    // MARK: - Public interface
    func addSceneObject(object: NSObject)
    {
        if !self.sceneObjects.contains(object)
        {
            self.sceneObjects.append(object)
        }
    }

    func removeSceneObject(object: NSObject)
    {
        if let index = self.sceneObjects.indexOf(object)
        {
            self.sceneObjects.removeAtIndex(index)
        }
    }

    // MARK: - Overriden interface
    override func layoutSubviews()
    {
        super.layoutSubviews()
        self.camera.aspect = fabsf(Float(self.bounds.size.width / self.bounds.size.height))
    }

    override func display()
    {
        super.display()
        glClearColor(0.0, 0.0, 0.0, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))

        let objects = self.sceneObjects
        for object in objects
        {
            if let renderable = object as? Renderable
            {
                renderable.render(self.camera)
            }
        }
    }
}
