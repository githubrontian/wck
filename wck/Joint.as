﻿package wck {		import Box2DAS.*;	import Box2DAS.Collision.*;	import Box2DAS.Collision.Shapes.*;	import Box2DAS.Common.*;	import Box2DAS.Dynamics.*;	import Box2DAS.Dynamics.Contacts.*;	import Box2DAS.Dynamics.Joints.*;	import cmodule.Box2D.*;	import wck.*;	import misc.*;	import flash.utils.*;	import flash.events.*;	import flash.display.*;	import flash.text.*;	import flash.geom.*;	import flash.ui.*;	import fl.motion.*;		/**	 * Wraps every Box2d joint type.	 */	public class Joint extends ScrollerChild {				/// See the Box2d documentation on joints for explanation of these variables:				[Inspectable(defaultValue=false)]		public var collideConnected:Boolean = false;				[Inspectable(defaultValue=0.0)]		public var lowerLimit:Number = 0.0;				[Inspectable(defaultValue=0.0)]		public var upperLimit:Number = 0.0;				[Inspectable(defaultValue=0.0)]		public var motorStrength:Number = 0.0;				[Inspectable(defaultValue=0.0)]		public var motorSpeed:Number = 0.0;				[Inspectable(defaultValue=false)]		public var enableLimit:Boolean = false;				[Inspectable(defaultValue=false)]		public var enableMotor:Boolean = false;				[Inspectable(defaultValue='None',enumeration='None,Distance,Line,Mouse,Prismatic,Pulley,Revolute,Weld,Friction')]		public var type:String = 'None';				[Inspectable(defaultValue=0)]		public var axisX:Number = 0;				[Inspectable(defaultValue=0)]		public var axisY:Number = 0;								[Inspectable(defaultValue=false)]		public var spring:Boolean = false;				[Inspectable(defaultValue=0.0)]		public var springConstant:Number = 0.0;				[Inspectable(defaultValue=0.0)]		public var springDamping:Number = 0.0;				[Inspectable(defaultValue=5.0)]		public var frequencyHz:Number = 5.0;				[Inspectable(defaultValue=0.7)]		public var dampingRatio:Number = 0.7;				[Inspectable(defaultValue=1.0)]		public var pulleyGearRatio:Number = 1.0;		[Inspectable(defaultValue='')]		public var target1Name:String = '';		[Inspectable(defaultValue='')]		public var target2Name:String = '';		[Inspectable(defaultValue='')]		public var pulleyGearPartnerName:String = '';					[Inspectable(defaultValue=false)]		public var gearCollideConnected:Boolean = false;				[Inspectable(defaultValue='')]		public var connectorClassName:String = '';				[Inspectable(defaultValue=2)]		public var connectorThickness:Number = 2;				[Inspectable(defaultValue=0.0)]		public var frictionForce:Number = 0.0;				[Inspectable(defaultValue=0.0)]		public var frictionTorque:Number = 0.0;				[Inspectable(defaultValue='#888888',type='Color')]		public var connectorColor:uint = 0x888888;				/// Mouse joints only - the position of the mouse joint will be passed to "SetTarget" each frame. This allows		/// mouse joints to be animated in flash via tweens.		[Inspectable(defaultValue=false)]		public var tweened:Boolean = false;				public var world:World;		public var b2joint:b2Joint;		public var target1Object:DisplayObject;		public var bodyShape1:BodyShape;		public var b2body1:b2Body;		public var target2Object:DisplayObject;		public var target2Joint:Joint;		public var bodyShape2:BodyShape;		public var b2body2:b2Body;		public var pulleyGearPartner:Joint;		public var b2gear:b2Joint;		public var anchorPoint:Point;		public var connector:Connector;				/**		 *		 */		public override function create():void {			locateBodies();			createAnchorPoint();			createJoint();			createConnector();			createSpring();			super.create();		}				/**		 *		 */		public override function destroy():void {			if(world && world.created) { /// Don't do anything if the world is being destroyed.				destroyConnector();				destroyGearJoint();				destroyJoint();				destroySpring();			}		}						/**		 * This function determines what bodies should be involved in a joint.		 */		public function locateBodies():void {			world = Util.findAncestorOfClass(this, World) as World;			world.ensureCreated();			var exclude:Array = [];			var autoFind:uint = 0;			target1Object = bodyShape1;			if(!target1Object && target1Name) {				target1Object = Util.getDisplayObjectByPath(this.parent, target1Name, world);				bodyShape1 = target1Object as BodyShape;			}			if(bodyShape1) {				exclude.push(bodyShape1);			}			else {				autoFind = 1;			}			if(type != 'Mouse') { /// Mouse joints always have only one body shape (the other is ground).				target2Object = bodyShape2;				if(!target2Object && target2Name) {					target2Object = Util.getDisplayObjectByPath(this.parent, target2Name, world);					bodyShape2 = target2Object as BodyShape;					target2Joint = target2Object as Joint;				}				else if(!bodyShape2 && !target2Joint) {					++autoFind;				}			}			if(autoFind > 0) {				var objs:Array = Util.getObjectsUnderPointByClass(world, localToGlobal(new Point(0, 0)), BodyShape, autoFind, exclude);				for(var i:int = 0; i < objs.length; ++i) {					if(bodyShape1) {						bodyShape2 = objs[i];						target2Object = bodyShape2;					}					else {						bodyShape1 = objs[i];						target1Object = bodyShape1;					}				}			}			if(bodyShape1) {				bodyShape1.ensureCreated();				b2body1 = bodyShape1.b2body;			}			else {				b2body1 = world.b2world.m_groundBody;			}			if(target2Joint) {				target2Joint.ensureCreated();				bodyShape2 = target2Joint.bodyShape1;			}			if(bodyShape2) {				bodyShape2.ensureCreated();				b2body2 = bodyShape2.b2body;			}			else {				b2body2 = world.b2world.m_groundBody;			}			if(!target2Object) {				target2Object = this;			}			if(!pulleyGearPartner && pulleyGearPartnerName) {				pulleyGearPartner = Util.getDisplayObjectByPath(this.parent, pulleyGearPartnerName, world) as Joint;			}			if(pulleyGearPartner) {				pulleyGearPartner.ensureCreated();			}						/// When object this joint depends on (targets) are removed, also remove this joint.			if(target1Object) {				listenWhileVisible(target1Object, Event.REMOVED_FROM_STAGE, handleTargetRemoved);			}			if(target2Object) {				listenWhileVisible(target2Object, Event.REMOVED_FROM_STAGE, handleTargetRemoved);			}			if(pulleyGearPartner) {				listenWhileVisible(pulleyGearPartner, Event.REMOVED_FROM_STAGE, handleTargetRemoved);				if(pulleyGearPartner.target2Object) {					listenWhileVisible(pulleyGearPartner.target2Object, Event.REMOVED_FROM_STAGE, handleTargetRemoved);				}			}		}				/**		 * Some object this joint depends on has been removed / destroyed!		 */		public function handleTargetRemoved(e:Event):void {			if(world && world.created) { /// Don't do anything if the world is being destroyed.				if(e.target == target1Object) {					remove();				}				else if(e.target == target2Object) {					destroyJoint();					destroyGearJoint();					destroyConnector();					if(type == 'Pulley') {						pulleyGearPartner.destroyConnector();					}				}				else if(e.target == pulleyGearPartner || (pulleyGearPartner && e.target == pulleyGearPartner.target2Object)) {					if(type == 'Pulley') {						destroyJoint();												destroyConnector();					}					else {						destroyGearJoint();					}				}			}		}				/**		 * Just dispatches to the appropriate joint creation function.		 */		public function createJoint():void {			if(b2body1 == b2body2) {				return;			}			switch(type) {				case 'Distance':					createDistanceJoint();					break;				case 'Line':					createLineJoint();					break;				case 'Mouse':					createMouseJoint();					break;				case 'Prismatic':					createPrismaticJoint();					if(pulleyGearPartner) {						createGearJoint();					}					break;				case 'Pulley':					createPulleyJoint();					break;				case 'Revolute':					createRevoluteJoint();					if(pulleyGearPartner) {						createGearJoint();					}					break;				case 'Weld':					createWeldJoint();					break;				case 'Friction':					createFrictionJoint();					break;			}			if(b2joint) {				listenWhileVisible(this, GoodbyeJointEvent.GOODBYE_JOINT, handleGoodbyeJoint);			}		}				/**		 * 		 */		public function handleGoodbyeJoint(e:GoodbyeJointEvent):void {			if(e.joint == b2joint) {				b2joint = null;			}			else if(e.joint == b2gear) {				b2gear = null;			}		}				/**		 *		 */		public function createAnchorPoint():void {			if(target1Object) {				anchorPoint = Util.localizePoint(target1Object, this);				if(!tweened) {					listenWhileVisible(world, World.TIME_STEP, updateAnchorPoint, false, -20);				}			}		}				/**		 *		 */		public function updateAnchorPoint(e:Event):void {			var p:Point = Util.localizePoint(parent, target1Object, anchorPoint);			x = p.x;			y = p.y;		}				/**		 * Destroy the b2Joint.		 */		public function destroyJoint():void {			if(b2joint) {				b2joint.destroy();				b2joint = null;			}		}				/**		 * Destroy the gear joint.		 */		public function destroyGearJoint():void {			if(b2gear) {				b2gear.destroy();				b2gear = null;			}		}				/**		 * Initialize shared joint definition properties.		 */		public function initJointDef(jd:b2JointDef):void {			jd.collideConnected = collideConnected;			jd.userData = this;		}				/**		 * Create a distance joint.		 */		public function createDistanceJoint():void {			initJointDef(b2Def.distanceJoint);			b2Def.distanceJoint.frequencyHz = frequencyHz;			b2Def.distanceJoint.dampingRatio = dampingRatio;			var wp1:Point = Util.localizePoint(world, this);			var wp2:Point = Util.localizePoint(world, target2Object);			b2Def.distanceJoint.Initialize(b2body1, b2body2, new V2(wp1.x / world.scale, wp1.y / world.scale), new V2(wp2.x / world.scale, wp2.y / world.scale));			b2joint = new b2DistanceJoint(world.b2world, b2Def.distanceJoint);		}				/**		 * Creates a line joint.		 */		public function createLineJoint():void {			initJointDef(b2Def.lineJoint);			b2Def.lineJoint.enableLimit = enableLimit;			b2Def.lineJoint.lowerTranslation = lowerLimit;			b2Def.lineJoint.upperTranslation = upperLimit;			b2Def.lineJoint.enableMotor = enableMotor;			b2Def.lineJoint.maxMotorForce = motorStrength;			b2Def.lineJoint.motorSpeed = motorSpeed;			var wp1:Point = Util.localizePoint(world, this);			var axis:V2;			var wp2:Point = Util.localizePoint(world, target2Object);			if(axisX == 0 && axisY == 0) {				axis = new V2(wp2.x - wp1.x, wp2.y - wp1.y);			}			else {				axis = new V2(axisX, axisY);			}			axis.normalize();			b2Def.lineJoint.Initialize(b2body1, b2body2, new V2(wp2.x / world.scale, wp2.y / world.scale), axis);			b2joint = new b2LineJoint(world.b2world, b2Def.lineJoint);		}				/**		 * Create a mouse joint.		 */		public function createMouseJoint():void {			initJointDef(b2Def.mouseJoint);			b2Def.mouseJoint.frequencyHz = frequencyHz;			b2Def.mouseJoint.dampingRatio = dampingRatio;			b2Def.mouseJoint.maxForce = motorStrength;			b2Def.mouseJoint.Initialize(b2body1, V2.fromP(Util.localizePoint(world, this)).divideN(world.scale));			b2joint = new b2MouseJoint(world.b2world, b2Def.mouseJoint);			if(tweened) {				listenWhileVisible(world, World.TIME_STEP, updateMouseJointTarget, false, 1);			}		}				/**		 *		 */		public function updateMouseJointTarget(e:Event):void {			(b2joint as b2MouseJoint).SetTarget(V2.fromP(Util.localizePoint(world, this)).divideN(world.scale));		}				/**		 * Create a prismatic joint.		 */		public function createPrismaticJoint():void {			initJointDef(b2Def.prismaticJoint);			b2Def.prismaticJoint.enableLimit = enableLimit;			b2Def.prismaticJoint.lowerTranslation = lowerLimit;			b2Def.prismaticJoint.upperTranslation = upperLimit;			b2Def.prismaticJoint.enableMotor = enableMotor;			b2Def.prismaticJoint.maxMotorForce = motorStrength;			b2Def.prismaticJoint.motorSpeed = motorSpeed;			var wp1:Point = Util.localizePoint(world, this);			var axis:V2;			if(axisX == 0 && axisY == 0) {				var wp2:Point = Util.localizePoint(world, target2Object);				axis = new V2(wp2.x - wp1.x, wp2.y - wp1.y);			}			else {				axis = new V2(axisX, axisY);			}			axis.normalize();			if(!b2body1.IsStatic() && b2body2.IsStatic()) { /// Make sure gears have a static body as body1				var flip:b2Body = b2body1;				b2body1 = b2body2;				b2body2 = flip;			}			b2Def.prismaticJoint.Initialize(b2body1, b2body2, new V2(wp1.x / world.scale, wp1.y / world.scale), axis);			b2joint = new b2PrismaticJoint(world.b2world, b2Def.prismaticJoint);					}				/**		 * Creates a pulley joint.		 */		public function createPulleyJoint():void {			initJointDef(b2Def.pulleyJoint);			b2Def.pulleyJoint.maxLengthA = lowerLimit;			b2Def.pulleyJoint.maxLengthB = upperLimit;			b2Def.pulleyJoint.ratio = pulleyGearRatio;			var wp1:Point = Util.localizePoint(world, this);			var wp2:Point = Util.localizePoint(world, pulleyGearPartner);			var gp1:Point = Util.localizePoint(world, target2Object);			var gp2:Point = Util.localizePoint(world, pulleyGearPartner.target2Object);			b2Def.pulleyJoint.Initialize(				b2body1, 				pulleyGearPartner.b2body1,				new V2(gp1.x / world.scale, gp1.y / world.scale),				new V2(gp2.x / world.scale, gp2.y / world.scale),				new V2(wp1.x / world.scale, wp1.y / world.scale),				new V2(wp2.x / world.scale, wp2.y / world.scale),				pulleyGearRatio);			b2joint = new b2PulleyJoint(world.b2world, b2Def.pulleyJoint);		}				/**		 * Create a revolute joint.		 */		public function createRevoluteJoint():void {			initJointDef(b2Def.revoluteJoint);			b2Def.revoluteJoint.enableLimit = enableLimit;			b2Def.revoluteJoint.lowerAngle = lowerLimit;			b2Def.revoluteJoint.upperAngle = upperLimit;			b2Def.revoluteJoint.enableMotor = enableMotor;			b2Def.revoluteJoint.maxMotorTorque = motorStrength;			b2Def.revoluteJoint.motorSpeed = motorSpeed;			var wp1:Point = Util.localizePoint(world, this);			if(!b2body1.IsStatic() && b2body2.IsStatic()) { /// Make sure gears have a static body as body1				var flip:b2Body = b2body1;				b2body1 = b2body2;				b2body2 = flip;			}			b2Def.revoluteJoint.Initialize(b2body1, b2body2, new V2(wp1.x / world.scale, wp1.y / world.scale));			b2joint = new b2RevoluteJoint(world.b2world, b2Def.revoluteJoint);		}				/**		 * Create a weld joint.		 */		public function createWeldJoint():void {			initJointDef(b2Def.weldJoint);			var wp1:Point = Util.localizePoint(world, this);			b2Def.weldJoint.Initialize(b2body1, b2body2, new V2(wp1.x / world.scale, wp1.y / world.scale));			b2joint = new b2WeldJoint(world.b2world, b2Def.weldJoint);		}				/**		 * Create a friction joint.		 */		public function createFrictionJoint():void {			initJointDef(b2Def.frictionJoint);			b2Def.frictionJoint.maxForce = frictionForce;			b2Def.frictionJoint.maxTorque = frictionTorque;			var wp1:Point = Util.localizePoint(world, this);			b2Def.frictionJoint.Initialize(b2body1, b2body2, new V2(wp1.x / world.scale, wp1.y / world.scale));			b2joint = new b2FrictionJoint(world.b2world, b2Def.frictionJoint);		}				/**		 * Creates a gear joint.		 */		public function createGearJoint():void {			initJointDef(b2Def.gearJoint);			b2Def.gearJoint.collideConnected = gearCollideConnected;			b2Def.gearJoint.Initialize(b2joint, pulleyGearPartner.b2joint, pulleyGearRatio);			b2gear = new b2GearJoint(world.b2world, b2Def.gearJoint);		}				/**		 * Create a connector object between the joint and the target2Object.		 */		public function createConnector():void {			if(target2Object && connectorClassName != '') {				var connectorClass:Class = getDefinitionByName(connectorClassName) as Class;				connector = new connectorClass() as Connector;				connector.from = this;				connector.to = target2Object;				var cl:ConnectorLine = connector as ConnectorLine;				if(cl) {					cl.color = connectorColor;					cl.thickness = connectorThickness;				}				world.addChild(connector);			}		}				/**		 * Destroy the connector.		 */		public function destroyConnector():void {			if(connector) {				Util.remove(connector);				connector = null;			}		}				/** 		 * Make the joint act as a spring. Only works for motor-enabled joints.		 */		public function createSpring():void {			if(spring) {				listenWhileVisible(world, World.TIME_STEP, updateSpring);			}		}				/**		 * Update the joint to act as a spring.		 */		public function updateSpring(e:Event):void {			var pj:b2PrismaticJoint = b2joint as b2PrismaticJoint;			var lj:b2LineJoint = b2joint as b2LineJoint;			var rj:b2RevoluteJoint = b2joint as b2RevoluteJoint			if(pj) {				var pjt:Number = pj.GetJointTranslation();				pj.SetMaxMotorForce(Math.abs((pjt * springConstant) + (pj.GetJointSpeed() * springDamping)));				pj.SetMotorSpeed(pjt > 0 ? -100000 : +100000);			}			else if(rj) {				var rja:Number = rj.GetJointAngle();				rj.SetMaxMotorTorque(Math.abs((rja * springConstant) + (rj.GetJointSpeed() * springDamping)));				rj.SetMotorSpeed(rja > 0 ? -100000 : +100000);			}			else if(lj) {				var ljt:Number = lj.GetJointTranslation();				lj.SetMaxMotorForce(Math.abs((ljt * springConstant) + (lj.GetJointSpeed() * springDamping)));				lj.SetMotorSpeed(ljt > 0 ? -100000 : +100000);			}		}				/**		 * Stop updating the joint to act as a spring.		 */		public function destroySpring():void {			stopListening(world, World.TIME_STEP, updateSpring);		}	}}