create or replace function it.xx_factura2 (p_nro_factura in varchar2)
return long is
v_factura long := '';
v_cabecera long :=
'<html>
<body dir=LTR bgcolor="#ffffff">
<!-- IT CONSULTORES -->
<div style="position: absolute; top:0pt;left:1pt;">
</div>
<div style="position:absolute;top:11.7pt;left:405.0pt;width:207.8;height:118.3;padding-top:110.6;font:0pt Arial;border-width:1.4; border-style:solid;border-color:#000000;"><table></table></div>
<style>#f1{font:bold 7pt "Arial";color:#000000}</style>
<span style="position:absolute;top:14pt;left:444pt" id=f1>&NRO_TIMBRADO</span>
<span style="position:absolute;top:35pt;left:455pt" id=f1>&NRO_RUC_ENTIDAD</span>
<span style="position:absolute;top:25pt;left:429pt" id=f1>&MES_VAL_TIMBRADO</span>
<style>#f2{font:bold 10pt "Arial";color:#000000}</style>
<span style="position:absolute;top:48pt;left:457pt" id=f2>&DES_TIP_COMPROBANTE</span>
<span style="position:absolute;top:61pt;left:442pt" id=f2>&NRO_FACTURA</span>
<style>#f3{font:8pt "Arial";color:#000000}</style>
<span style="position:absolute;top:74pt;left:553pt" id=f3> </span>
<span style="position:absolute;top:85pt;left:553pt" id=f3> </span>
<div style="position:absolute;top:11.7pt;left:24pt;width:503;height:118.3;padding-top:111.8;font:0pt Arial;border-width:1.4; border-style:solid;border-color:#000000;"><table></table></div>
<style>#f4{font:bold 8pt "Arial";color:#000000}</style>
<span style="position:absolute;top:26pt;left:257pt" id=f4>INTERMEDIACION FINANCIERA</span>
<span style="position: absolute; top:17.2pt;left:28.7pt; width:111.0pt;height:33.8pt; "><img src=logo_br.gif width=164 height=57 border=0"> </span>
<span style="position:absolute;top:59pt;left:31pt" id=f1>&NOM_ENTIDAD</span>
<style>#f5{font:6pt "Arial";color:#000000}</style>
<span style="position:absolute;top:69pt;left:31pt" id=f5>&DIR_OFICINA</span>
<span style="position:absolute;top:76pt;left:31pt" id=f5>&DIR_MATRIZ</span>
<span style="position:absolute;top:83pt;left:31pt" id=f4> </span>
<div style="position:absolute;top:103.1pt;left:24.0pt;width:715.5;height:67.5;padding-top:59.8;font:0pt Arial;border-width:1.4; border-style:solid;border-color:#000000;"><table></table></div>
<span style="position:absolute;top:108pt;left:113pt" id=f3>&FEC_EMISION</span>
<span style="position:absolute;top:108pt;left:26pt" id=f3>Fecha de Emision:</span>
<span style="position:absolute;top:108pt;left:350pt" id=f3>Condicion de Venta:  Contado&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Credito</span>
<div style="position:absolute;top:109.5pt;left:459.9pt;width:13.5;height:13.5;padding-top:5.8;font:0pt Arial;border-width:1.4; border-style:solid;border-color:#000000;"><table></table></div>
<div style="position:absolute;top:109.1pt;left:529.6pt;width:13.5;height:13.5;padding-top:5.8;font:0pt Arial;border-width:1.4; border-style:solid;border-color:#000000;"><table></table></div>
<span style="position:absolute;top:109pt;left:461pt" id=f4>&MAR_CONTADO</span>
<span style="position:absolute;top:109pt;left:531pt" id=f4>&MAR_CREDITO</span>
<span style="position:absolute;top:122pt;left:474pt" id=f3>&NRO_DOC_CLIENTE</span>
<span style="position:absolute;top:122pt;left:433pt" id=f3>R.U.C.:</span>
<span style="position:absolute;top:122pt;left:113pt" id=f3>&NOM_CLIENTE</span>
<span style="position:absolute;top:122pt;left:26pt" id=f3>Nombre o Razon Social:</span>
<span style="position:absolute;top:136pt;left:113pt" id=f3>&DIR_CLIENTE</span>
<span style="position:absolute;top:136pt;left:26pt" id=f3>Direccion:</span>
<span style="position:absolute;top:136pt;left:474pt" id=f3>583088</span>
<span style="position:absolute;top:136pt;left:433pt" id=f3>Telefono:</span>
<div style="position:absolute;top:459.5pt;left:24.0pt;width:715;height:32.4;padding-top:24.8;font:0pt Arial;border-width:1.4; border-style:solid;border-color:#000000;"><table></table></div>
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
<span style="position:absolute;top:501pt;left:30pt" id=f11>&DES_TOTAL</span>
<div style="position:absolute;top:482.7pt;left:438.8pt;width:2.8;height:72.6;padding-top:64.9;font:0pt Arial;border-width:0 0 0 1.4; border-style:solid;border-color:#000000;"><table></table></div>
<div style="position:absolute;top:535.5pt;left:24.0pt;width:715.5;height:2.8;padding-top:-4.8;font:0pt Arial;border-width:1.4 0 0 0; border-style:solid;border-color:#000000;"><table></table></div>
<span style="position:absolute;top:539pt;left:154pt" id=f8>&TOT_IVA_5</span>
<span style="position:absolute;top:539pt;left:133pt" id=f1>(5%)</span>
<span style="position:absolute;top:539pt;left:283pt" id=f8>&TOT_IVA_10</span>
<span style="position:absolute;top:539pt;left:258pt" id=f1>(10%)</span>
<span style="position:absolute;top:539pt;left:428pt" id=f8>&TOT_IVA</span>
<span style="position:absolute;top:539pt;left:389pt" id=f1>TOTAL IVA</span>
<span style="position:absolute;top:539pt;left:30pt" id=f1>LIQUIDACION DEL IVA</span>
<span style="position:absolute;top:556pt;left:28pt" id=f8>&TIP_IMPRESION</span>
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
'Timbrado N? '||nro_timbrado nro_timbrado, 
'Valido hasta '||fug_des_mes(a.fec_vig_timbrado)||' de '||to_char(a.fec_vig_timbrado,'yyyy') mes_validez,
fecha, 
c.Oficina,
c.oficina||', '||fug_des_fecha(fecha) des_fecha, 
tip_comprobante,
b.significado des_tip_comprobante, 
a.tip_venta tip_venta,
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
decode(a.tip_comprobante,'N','TOTAL A ACREDITAR  ','TOTAL A PAGAR  ')||fue_obt_denominacion(nvl(mto_exento,0) + nvl(mto_gravado_5,0) + nvl(mto_gravado_10,0)+nvl(impuesto_5,0)+nvl(impuesto_10,0))||'.-' des_tot_venta,
decode(nro_fac_referencia,'0',null,nro_fac_referencia) nro_fac_referencia, 
decode(nro_tim_referencia,'0',null,nro_tim_referencia) nro_tim_referencia, 
decode(impreso,'N','ORIGINAL','COPIA') tip_impresion,
c.nom_entidad,
'RUC ' ||c.ruc_entidad ruc_entidad,
c.matriz,
c.direccion dir_oficina,
c.telefono tel_oficina,
a.rowid fila,
a.impreso
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
   AND a.nro_factura = p_nro_factura
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
  PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
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
    v_factura := replace(v_factura,'&DES_TIP_COMPROBANTE',c.des_tip_comprobante);    
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
    v_factura := replace(v_factura,'&TIP_IMPRESION',c.tip_impresion);
    if c.tip_venta = 'CR' THEN 
       v_factura := replace(v_factura,'&MAR_CONTADO','');   
       v_factura := replace(v_factura,'&MAR_CREDITO','X');
    else  
       v_factura := replace(v_factura,'&MAR_CONTADO','X');   
       v_factura := replace(v_factura,'&MAR_CREDITO','');    
    end if;  
    -- actualizo la impresion
    if c.impreso = 'N' then
       begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
       update cb_lib_ventas 
          set impreso = 'S'
        where rowid = c.fila;
    end if;  
  end loop;
  commit;
  return v_factura;
end;
/

