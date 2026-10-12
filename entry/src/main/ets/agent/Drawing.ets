export interface DrawingPoint {x:number;y:number;}
export interface DrawingBounds {left:number;top:number;right:number;bottom:number;}
export interface DrawingRequest {strokes:DrawingPoint[][];speed:number;tool:string;}
export function drawingRequest(raw:string,tool:string='finger',speed:number=20):DrawingRequest{
 if(tool!=='finger')throw new Error('当前未验证电容笔注入，请使用 finger');
 if(!Number.isFinite(speed))throw new Error('绘制速度需要有限数字');
 const input=JSON.parse(raw) as number[][][];
 if(!Array.isArray(input)||!input.length||input.length>20)throw new Error('每次需要1～20笔');
 let total=0;const strokes:DrawingPoint[][]=[];
 for(const stroke of input){
  if(!Array.isArray(stroke)||stroke.length<2||stroke.length>200)throw new Error('每笔需要2～200个点');
  total+=stroke.length;if(total>1500)throw new Error('总点数不能超过1500');
  const points:DrawingPoint[]=[];
  for(const point of stroke){if(!Array.isArray(point)||point.length!==2||typeof point[0]!=='number'||typeof point[1]!=='number'||!Number.isFinite(point[0])||!Number.isFinite(point[1])||point[0]<0||point[0]>1000||point[1]<0||point[1]>1000)throw new Error('坐标需要0～1000的有限数字');points.push({x:point[0],y:point[1]});}
  strokes.push(points);
 }
 return {strokes,speed:Math.round(Math.max(5,Math.min(100,speed))),tool};
}
export function drawingPixels(request:DrawingRequest,width:number,height:number,bounds?:DrawingBounds):DrawingPoint[][]{
 if(!Number.isFinite(width)||!Number.isFinite(height)||width<2||height<2)throw new Error('屏幕尺寸无效');
 const output:DrawingPoint[][]=[];
 for(const stroke of request.strokes){const result:DrawingPoint[]=[];
  for(let i=0;i<stroke.length;i++){const point:DrawingPoint={x:Math.round(stroke[i].x*(width-1)/1000),y:Math.round(stroke[i].y*(height-1)/1000)};
   if(bounds&&(point.x<bounds.left||point.y<bounds.top||point.x>=bounds.right||point.y>=bounds.bottom))throw new Error('绘制点超出画布边界');
   const previous=result[result.length-1];if(!previous||Math.hypot(previous.x-point.x,previous.y-point.y)>=3||i===stroke.length-1)result.push(point);
  }
  if(result.length<2||result.every(p=>p.x===result[0].x&&p.y===result[0].y))throw new Error('绘制路径没有有效移动');output.push(result);
 }
 return output;
}
