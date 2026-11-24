create or replace function it.xx_factura (p_nro_factura in varchar2)
return long is
v_factura long := '';
v_cabecera long :=
'<html>
<body dir=LTR bgcolor="#ffffff">
<!-- Factura -->
<div style="position: absolute; top:0pt;left:1pt;">
</div>
<div style="position:absolute;top:11.7pt;left:408.0pt;width:203.8;height:118.3;padding-top:110.6;font:0pt Arial;border-width:1.4; border-style:solid;border-color:#000000;"><table></table></div>
<style>#f1{font:bold 7pt "Arial";color:#000000}</style>
<span style="position:absolute;top:14pt;left:468pt" id=f1>&NRO_TIMBRADO</span>
<span style="position:absolute;top:14pt;left:415pt" id=f1>TIMBRADO No.</span>
<span style="position:absolute;top:24pt;left:415pt" id=f1>Valido hasta </span>
<span style="position:absolute;top:35pt;left:436pt" id=f1>&NRO_RUC_ENTIDAD</span>
<span style="position:absolute;top:35pt;left:415pt" id=f1>RUC:</span>
<span style="position:absolute;top:25pt;left:459pt" id=f1>&MES_VAL_TIMBRADO</span>
<style>#f2{font:bold 10pt "Arial";color:#000000}</style>
<span style="position:absolute;top:48pt;left:414pt" id=f2>FACTURA CONTADO</span>
<span style="position:absolute;top:61pt;left:432pt" id=f2>&NRO_FACTURA</span>
<style>#f3{font:bold 8pt "Arial";color:#000000}</style>
<span style="position:absolute;top:62pt;left:413pt" id=f3>Nro.</span>
<style>#f4{font:8pt "Arial";color:#000000}</style>
<span style="position:absolute;top:74pt;left:553pt" id=f4> </span>
<span style="position:absolute;top:85pt;left:553pt" id=f4> </span>
<div style="position:absolute;top:11.7pt;left:24pt;width:509;height:119.5;padding-top:111.8;font:0pt Arial;border-width:1.4; border-style:solid;border-color:#000000;"><table></table></div>
<span style="position:absolute;top:26pt;left:257pt" id=f3>INTERMEDIACION FINANCIERA</span>
<span style="position: absolute; top:17.2pt;left:28.7pt; width:111.0pt;height:38.6pt; "><img src=blcomven0.gif width=148 height=51 border=0"> </span>
<span style="position:absolute;top:57pt;left:31pt" id=f1>&NOM_ENTIDAD</span>
<style>#f5{font:6pt "Arial";color:#000000}</style>
<span style="position:absolute;top:67pt;left:31pt" id=f5>&DIR_OFICINA</span>
<span style="position:absolute;top:74pt;left:31pt" id=f5>&DIR_MATRIZ.</span>
<style>#f6{font:6pt "Arial";color:#000000}</style>
<span style="position:absolute;top:83pt;left:31pt" id=f6>Aprobado Segun S.S.E.T. / C.C. No. 123 de Fecha 02/10/02</span>
<div style="position:absolute;top:103.1pt;left:24.0pt;width:715.5;height:67.5;padding-top:59.8;font:0pt Arial;border-width:1.4; border-style:solid;border-color:#000000;"><table></table></div>
<span style="position:absolute;top:108pt;left:113pt" id=f4>&FEC_EMISION</span>
<span style="position:absolute;top:108pt;left:26pt" id=f4>Fecha de Emision:</span>
<span style="position:absolute;top:122pt;left:474pt" id=f4>&NRO_DOC_CLIENTE</span>
<span style="position:absolute;top:122pt;left:433pt" id=f4>R.U.C.:</span>
<span style="position:absolute;top:122pt;left:113pt" id=f4>&NOM_CLIENTE</span>
<span style="position:absolute;top:122pt;left:26pt" id=f4>Nombre o Razon Social:</span>
<span style="position:absolute;top:136pt;left:113pt" id=f4>&DIR_CLIENTE</span>
<span style="position:absolute;top:136pt;left:26pt" id=f4>Direccion:</span>
<span style="position:absolute;top:136pt;left:474pt" id=f4>&TEL_CLIENTE</span>
<span style="position:absolute;top:136pt;left:433pt" id=f4>Telefono:</span>
<div style="position:absolute;top:459.5pt;left:24.0pt;width:715.5;height:32.4;padding-top:24.8;font:0pt Arial;border-width:1.4; border-style:solid;border-color:#000000;"><table></table></div>
<div style="position:absolute;top:155.7pt;left:24.0pt;width:715.5;height:530.4;padding-top:522.8;font:0pt Arial;border-width:1.4; border-style:solid;border-color:#000000;"><table></table></div>
<span style="position:absolute;top:160pt;left:121pt" id=f4>DESCRIPCION</span>
<span style="position:absolute;top:158pt;left:410pt" id=f4>VALOR DE VENTA</span>
<div style="position:absolute;top:170.6pt;left:330.8pt;width:306.4;height:2.8;padding-top:-4.8;font:0pt Arial;border-width:1.4 0 0 0; border-style:solid;border-color:#000000;"><table></table></div>
<style>#f7{font:8pt "Arial";color:#000000}</style>
<span style="position:absolute;top:164pt;left:25pt" id=f7>Cant</span>
<div style="position:absolute;top:160pt;left:280pt" id=f4>PRECIO</div>
<div style="position:absolute;top:169pt;left:276pt" id=f4>UNITARIO</div>
<span style="position:absolute;top:172pt;left:350pt" id=f4>EXENTAS</span>
<span style="position:absolute;top:172pt;left:437pt" id=f4>5 %</span>
<span style="position:absolute;top:172pt;left:519pt" id=f4>10 %</span>
<style>#f8{font:7pt "Arial";color:#000000}</style>
<span style="position:absolute;top:173pt;left:43pt" id=f8>Cuenta</span>
<span style="position:absolute;top:173pt;left:81pt" id=f8>Numero</span>
<span style="position:absolute;top:173pt;left:117pt" id=f8>Fecha</span>
<span style="position:absolute;top:173pt;left:148pt" id=f8>Concepto</span>
<div style="position:absolute;top:183.7pt;left:24.0pt;width:715.5;height:2.8;padding-top:-4.8;font:0pt Arial;border-width:1.4 0 0 0; border-style:solid;border-color:#000000;"><table></table></div>
<style>#f9{font:7pt "Arial";color:#000000}</style>
';

v_pie long := '<span style="position:absolute;top:467pt;left:358pt" id=f1>&TOT_EXENTO</span>
<span style="position:absolute;top:467pt;left:432pt" id=f1>&TOT_GRA_5</span>
<span style="position:absolute;top:467pt;left:509pt" id=f1>&TOT_GRA_10</span>
<span style="position:absolute;top:467pt;left:26pt" id=f1>SUBTOTALES</span>
<div style="position:absolute;top:155.7pt;left:41.7pt;width:2.8;height:406.6;padding-top:398.9;font:0pt Arial;border-width:0 0 0 1.4; border-style:solid;border-color:#000000;"><table></table></div>
<div style="position:absolute;top:155.7pt;left:258.5pt;width:2.8;height:406.6;padding-top:398.9;font:0pt Arial;border-width:0 0 0 1.4; border-style:solid;border-color:#000000;"><table></table></div>
<div style="position:absolute;top:170.7pt;left:482.5pt;width:2.8;height:417.5;padding-top:409.8;font:0pt Arial;border-width:0 0 0 1.4; border-style:solid;border-color:#000000;"><table></table></div>
<div style="position:absolute;top:170.7pt;left:405.7pt;width:2.8;height:417.5;padding-top:409.8;font:0pt Arial;border-width:0 0 0 1.4; border-style:solid;border-color:#000000;"><table></table></div>
<div style="position:absolute;top:155.8pt;left:330.3pt;width:2.8;height:437.4;padding-top:429.7;font:0pt Arial;border-width:0 0 0 1.4; border-style:solid;border-color:#000000;"><table></table></div>
<style>#f10{font:bold 12pt "Arial";color:#000000}</style>
<span style="position:absolute;top:501pt;left:443pt" id=f10>&MTO_TOTAL</span>
<style>#f11{font:bold 7pt "Arial";color:#000000}</style>
<span style="position:absolute;top:501pt;left:99pt" id=f11>&DES_TOTAL</span>
<span style="position:absolute;top:501pt;left:30pt" id=f1>TOTAL A  PAGAR</span>
<div style="position:absolute;top:482.7pt;left:438.8pt;width:2.8;height:72.6;padding-top:64.9;font:0pt Arial;border-width:0 0 0 1.4; border-style:solid;border-color:#000000;"><table></table></div>
<div style="position:absolute;top:535.5pt;left:24.0pt;width:715.5;height:2.8;padding-top:-4.8;font:0pt Arial;border-width:1.4 0 0 0; border-style:solid;border-color:#000000;"><table></table></div>
<span style="position:absolute;top:539pt;left:154pt" id=f8>&TOT_IVA_5</span>
<span style="position:absolute;top:539pt;left:133pt" id=f1>(5%)</span>
<span style="position:absolute;top:539pt;left:283pt" id=f8>&TOT_IVA_10</span>
<span style="position:absolute;top:539pt;left:258pt" id=f1>(10%)</span>
<span style="position:absolute;top:539pt;left:428pt" id=f8>&TOT_IVA</span>
<span style="position:absolute;top:539pt;left:389pt" id=f1>TOTAL IVA</span>
<span style="position:absolute;top:539pt;left:30pt" id=f1>LIQUIDACION DEL IVA</span>
<span style="position:absolute;top:556pt;left:28pt" id=f8>ORIGINAL</span>
<div style="position:absolute;top:555pt;left:431pt" id=f1>ORIGINAL: COMPRADOR</div>
<div style="position:absolute;top:563pt;left:431pt" id=f1>DUPLICADO: ARCHIVO TRIBUTARIO</div>
<div style="position: absolute; top:838pt;left:1pt;">
</div>
<div style="position: absolute; top:854pt;left:1pt;"></div>
</body></html>';
v_detalle_01 varchar2(1000) := '
<span style="position:absolute;top:&POSpt;left:29pt" id=f9>&CAN</span>
<span style="position:absolute;top:&POSpt;left:44pt" id=f9>&CTA</span>
<span style="position:absolute;top:&POSpt;left:82pt" id=f9>&REC</span>
<span style="position:absolute;top:&POSpt;left:116pt" id=f9>&FEC</span>
<span style="position:absolute;top:&POSpt;left:147pt" id=f9>&DES</span>
<span style="position:absolute;top:&POSpt;left:282pt" id=f9>&PRE</span>
<span style="position:absolute;top:&POSpt;left:363pt" id=f9>&EXE</span>
<span style="position:absolute;top:&POSpt;left:434pt" id=f9>&GRA5</span>
<span style="position:absolute;top:&POSpt;left:515pt" id=f9>&GRA10</span>';
v_detalle_02 varchar2(1000) := '
<div style="position:absolute;top:&POS.1pt;left:25.1pt;width:713.0;height:14.6;layer-background-color:#eaeaea;background-color:#eaeaea;border-width:1; border-style:none"><table></table></div>
<span style="position:absolute;top:&POSpt;left:29pt" id=f9>&CAN</span>
<span style="position:absolute;top:&POSpt;left:44pt" id=f9>&CTA</span>
<span style="position:absolute;top:&POSpt;left:82pt" id=f9>&REC</span>
<span style="position:absolute;top:&POSpt;left:116pt" id=f9>&FEC</span>
<span style="position:absolute;top:&POSpt;left:147pt" id=f9>&DES</span>
<span style="position:absolute;top:&POSpt;left:282pt" id=f9>&PRE</span>
<span style="position:absolute;top:&POSpt;left:363pt" id=f9>&EXE</span>
<span style="position:absolute;top:&POSpt;left:434pt" id=f9>&GRA5</span>
<span style="position:absolute;top:&POSpt;left:515pt" id=f9>&GRA10</span>
';
cursor cabecera is
  SELECT nro_factura, 
  nro_timbrado, 
  fug_des_mes(a.fec_vig_timbrado)||' de '||to_char(a.fec_vig_timbrado,'yyyy') mes_validez,
  fecha, 
  c.Oficina,
  c.oficina||', '||fug_des_fecha(fecha) des_fecha, 
  tip_comprobante,
  b.significado des_tip_comprobante, 
  b.significado||' '||DECODE(tip_venta,'CR','CREDITO','CONTADO') TIP_VENTA, 
  nro_documento||'-'||dig_verificador nro_ruc,
  nom_completo, 
  a.direccion,
  a.telefono,
  mto_exento, 
  replace(to_char(nvl(mto_gravado_5,0)+nvl(impuesto_5,0),'999G999G999G999G999'),',','.')  mto_gravado_5, 
  replace(to_char(nvl(mto_gravado_10,0)+nvl(impuesto_10,0),'999G999G999G999G999'),',','.')  mto_gravado_10, 
  replace(to_char(nvl(mto_exento,0) + nvl(mto_gravado_5,0) + nvl(mto_gravado_10,0)+nvl(impuesto_5,0)+nvl(impuesto_10,0),'999G999G999G999G999'),',','.')||'.-'  tot_venta, 
  ltrim(replace(to_char(impuesto_5,'999G999G999G999G999'),',','.'))  impuesto_5, 
  ltrim(replace(to_char(impuesto_10,'999G999G999G999G999'),',','.'))  impuesto_10, 
  ltrim(replace(to_char(nvl(impuesto_5,0) + nvl(impuesto_10,0),'999G999G999G999G999'),',','.'))   tot_iva,
  fue_obt_denominacion(nvl(mto_exento,0) + nvl(mto_gravado_5,0) + nvl(mto_gravado_10,0)+nvl(impuesto_5,0)+nvl(impuesto_10,0))||'.-' des_tot_venta,
  nro_fac_referencia, 
  nro_tim_referencia, 
  decode(impreso,'N','ORIGINAL','COPIA') tip_impresion,
  c.nom_entidad,
  c.ruc_entidad,
  c.matriz,
  c.direccion dir_oficina,
  c.telefono tel_oficina
  FROM BA_COD_REFERENCIAS B, CB_LIB_VENTAS A,
        (select b.cod_oficina cod_oficina, a.nom_entidad, c.nro_documento ruc_entidad, 
        fue_obt_titulo(b.descripcion) Oficina,
        d.direccion ||' - '||fue_obt_titulo(d.descripcion)||' - Py.' matriz,
        b.direccion ||' - '||fue_obt_titulo(b.descripcion)||' - Py.' direccion , b.telefono
        --  into v_nom_entidad, v_nro_ruc, v_des_oficina, v_dir_oficina, v_tel_oficina
          from ba_personas c, ba_oficinas d, ba_oficinas b, ge_par_generales a
         where d.cod_oficina = a.cod_ofi_matriz
           and c.cod_persona = a.cod_persona
           and b.estado = 'A') C
  WHERE B.DOMINIO = 'TIP_COM_VENTA'
    AND A.TIP_COMPROBANTE = B.VAL_MINIMO
    AND C.cod_oficina = a.cod_oficina   
    --AND A.NRO_FACTURA LIKE '001%00003'
    AND A.NRO_FACTURA = p_nro_factura
  order by nro_factura;
-- cursor de detalles
cursor detalles is
select 1 cantidad,
       fue_obt_titulo(a.descripcion) descripcion,
       REPLACE(TO_CHAR(nvl(a.mto_exento_gs,0) + nvl(a.mto_gra_5_gs,0) + nvl(a.mto_gra_10_gs,0)+nvl(a.impuesto_5_gs,0)+nvl(a.impuesto_10_gs,0),'999G999G999G999G999'),',','.') precio,
       REPLACE(TO_CHAR(a.mto_exento_gs,'999G999G999G999G999'),',','.')  mto_exento,
       REPLACE(TO_CHAR(nvl(a.mto_gra_5_gs,0)+nvl(a.impuesto_5_gs,0),'999G999G999G999G999'),',','.')   mto_gra_5,
       REPLACE(TO_CHAR(nvl(a.mto_gra_10_gs,0)+nvl(a.impuesto_10_gs,0),'999G999G999G999G999'),',','.')  mto_gra_10 ,
       to_char(a.fecha,'dd/mm/yy') fec_linea,
       a.nro_documento,
       a.nro_cuenta
from cb_lib_ventas_det a
WHERE A.NRO_FACTURA = p_nro_factura
order by fecha, hora;
v_detalles long := null;
v_cantidad number := 0;
v_pos number := 187;
v_det varchar2(1000);
begin
  
  for d in detalles loop
      v_cantidad := v_cantidad + 1;
      if v_cantidad / 2 = trunc(v_cantidad / 2) then
         v_det := v_detalle_01;
      else
         v_det := v_detalle_02;
      end if;
  
      v_det := replace(v_det,'&CAN',d.cantidad);
      v_det := replace(v_det,'&REC',d.nro_documento);
      v_det := replace(v_det,'&CTA',d.nro_cuenta);
      v_det := replace(v_det,'&FEC',d.fec_linea);
      v_det := replace(v_det,'&DES',d.descripcion);
      v_det := replace(v_det,'&PRE',d.precio);
      v_det := replace(v_det,'&EXE',d.mto_exento);
      v_det := replace(v_det,'&GRA5',d.mto_gra_5);
      v_det := replace(v_det,'&GRA10',d.mto_gra_10);
      v_det := replace(v_det,'&POS',v_pos);
      v_detalles := v_detalles || v_det;
      v_pos := v_pos + 11;
     
  end loop;
  v_factura := v_cabecera ||v_detalles|| v_pie;
  for c in cabecera loop
    v_factura := replace(v_factura,'&NRO_FACTURA',c.nro_factura);
    v_factura := replace(v_factura,'&NRO_TIMBRADO',c.nro_timbrado);
    v_factura := replace(v_factura,'&NRO_RUC_ENTIDAD',c.ruc_entidad);
    v_factura := replace(v_factura,'&MES_VAL_TIMBRADO',c.mes_validez);
    v_factura := replace(v_factura,'&NOM_ENTIDAD',c.nom_entidad);  
    v_factura := replace(v_factura,'&DIR_OFICINA',c.dir_oficina);        
    v_factura := replace(v_factura,'&DIR_MATRIZ',c.matriz);    
    v_factura := replace(v_factura,'&FEC_EMISION',c.des_fecha);
    v_factura := replace(v_factura,'&NRO_DOC_CLIENTE',c.nro_ruc);
    v_factura := replace(v_factura,'&NOM_CLIENTE',c.nom_completo);
    v_factura := replace(v_factura,'&DIR_CLIENTE',c.direccion);
    v_factura := replace(v_factura,'&TEL_CLIENTE',c.telefono);
    v_factura := replace(v_factura,'&TOT_EXENTO',c.mto_exento);
    v_factura := replace(v_factura,'&TOT_GRA_5',c.mto_gravado_5);
    v_factura := replace(v_factura,'&TOT_GRA_10',c.mto_gravado_10);
    v_factura := replace(v_factura,'&MTO_TOTAL',c.tot_venta); 
    v_factura := replace(v_factura,'&DES_TOTAL',c.des_tot_venta);    
    v_factura := replace(v_factura,'&TOT_IVA_5',c.impuesto_5);    
    v_factura := replace(v_factura,'&TOT_IVA_10',c.impuesto_10);    
    v_factura := replace(v_factura,'&TOT_IVA',c.tot_iva);    
  end loop;
    return v_factura;
end;
/

