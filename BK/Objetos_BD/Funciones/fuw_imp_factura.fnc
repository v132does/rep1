create or replace function it.fuw_imp_factura
 (p_cod_persona in varchar2, p_nro_factura in varchar2 default null)
return clob is
v_factura clob := '';
v_nro_factura varchar2(50);
v_cabecera clob :=
'<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title>Factura</title>
<style type="text/css">
.grande_negrita {
  font-family: Verdana, Geneva, sans-serif;
  font-size: 12px;
  font-weight: bold;
}
.grande_normal {
  font-family: Verdana, Geneva, sans-serif;
  font-size: 12px;
  font-weight: normal;
}
.item {
  font-family: Verdana, Geneva, sans-serif;
  font-size: 13px;
  font-weight: normal;
}
.chico {
  font-family: Verdana, Geneva, sans-serif;
  font-size: 9px;
}
.chico_bold {
  font-family: Verdana, Geneva, sans-serif;
  font-size: 9px;
  font-weight: bold;
}
</style>
</head>

<body>
<table width="850" border="1" cellpadding="0" cellspacing="3">
  <tr>
    <td width="520"><table width="100%" border="0" cellpadding="2" cellspacing="0">
        <tr>
          <td><img src="../images/logoweb.gif" alt="Logo" /></td>
          <td align="right"><strong class="grande_negrita">INTERMEDIACI&Oacute;N FINANCIERA</strong></td>
        </tr>
        <tr>
          <td colspan="2"><span class="grande_negrita">&NOM_ENTIDAD</span></td>
        </tr>
        <tr>
          <td colspan="2"><span class="grande_negrita">&DIR_OFICINA</span></td>
        </tr>
        <tr>
          <td colspan="2"><span class="grande_negrita">&DIR_MATRIZ</span></td>
        </tr>
      </table></td>
    <td width="264" align="center"><p class="grande_negrita">&NRO_TIMBRADO<br />
        &MES_VAL_TIMBRADO<br />
        &NRO_RUC_ENTIDAD<br />
        <br />
        <strong>&DES_TIP_COMPROBANTE<br />
        &NRO_FACTURA</strong></p></td>
  </tr>
</table>
<table width="850" border="1" cellpadding="0" cellspacing="0">
  <tr>
    <td width="549" valign="middle"><table width="100%" border="0">
        <tr>
          <td width="151" class="grande_negrita">Fecha de Emisi&oacute;n:<br />
            Nombre o Raz&oacute;n Social:<br />
            Direcci&oacute;n:<br />
            Per&iacute;odo de Facturaci&oacute;n:</td>
          <td width="338"><span class="grande_normal">&FEC_EMISION<br />
            &NOM_CLIENTE<br />
            &DIR_CLIENTE<br />
          &PER_FACTURACION</span><br /></td>
        </tr>
      </table></td>
    <td width="280" align="center" valign="top"><p class="grande_negrita"><br />
Condici&oacute;n de Venta: &MAR_CONDICION<br />
        <br />
        R.U.C.: &NRO_DOC_CLIENTE<br />
        Tel&eacute;fono: &TEL_CLIENTE</p></td>
  </tr>
</table>
<table width="850" border="1" cellpadding="0" cellspacing="0">
  <tr>
    <td width="40" rowspan="2" valign="bottom"><span class="chico_bold">Cant.</span></td>
    <td colspan="4" align="center"><span class="chico_bold">DESCRIPCI&Oacute;N</span></td>
    <td colspan="3" align="center"><span class="chico_bold">VALOR DE VENTA</span></td>
  </tr>
  <tr>
    <td width="80" align="center"><span class="chico_bold">Cuenta</span></td>
    <td width="69" align="center"><span class="chico_bold">N&uacute;mero</span></td>
    <td width="55" align="center"><span class="chico_bold">Fecha</span></td>
    <td width="307" align="left"><span class="chico_bold">Concepto</span></td>
    <td width="91" align="center"><span class="chico_bold">EXENTAS</span></td>
    <td width="84" align="center"><span class="chico_bold">5%</span></td>
    <td width="106" align="center"><span class="chico_bold">10%</span></td>
  </tr>';

v_pie clob := '<tr>
    <td colspan="5"><strong class="grande_negrita">SUBTOTALES</strong></td>
    <td align="center" class="grande_normal">&TOT_EXENTO</td>
    <td align="center" class="grande_normal">&TOT_GRA_5</td>
    <td align="center" class="grande_normal">&TOT_GRA_10</td>
  </tr>
  <tr height=25>
    <td colspan="6" class="grande_normal">&DES_TOTAL</td>
    <td colspan="2" align="center"><strong>&MTO_TOTAL</strong></td>
  </tr>
</table>
<table width="850" border="1" cellpadding="0" cellspacing="0">
  <tr>
    <td width="549" height="25" valign="middle"><table width="100%" border="0" cellpadding="0" cellspacing="0">
        <tr>
          <td width="212" height="19" valign="middle"><strong>LIQUIDACI&Oacute;N DEL IVA</strong></td>
          <td width="132" align="left" valign="top"><span class="grande_negrita">(5%)</span><span class="grande_normal"> &TOT_IVA_5</span><br /></td>
          <td width="153" align="left" valign="top"><span class="grande_negrita">(10%)</span><span class="grande_normal"> &TOT_IVA_10</span></td>
          <td width="349" align="left" valign="top"><span class="grande_negrita">TOTAL IVA</span>: <span class="grande_normal">&TOT_IVA</span></td>
        </tr>
      </table></td>
  </tr>
</table>
<table width="850" border="0" cellpadding="0" cellspacing="0">
  <tr>
    <td width="298" height="13" valign="middle"><span class="chico">BANCO BILBAO VISCAYA ARGENTARIA Paraguay S.A.</span></td>
    <td width="178" valign="middle"></td>
    <td width="366" align="right" valign="middle"><span class="chico">Autoriz. Como autoimpresor y Tim, Habilitaci&oacute;n No. 69.303</span></td>
  </tr>
  <tr>
    <td height="12" valign="middle"><span class="chico">&TIP_IMPRESION</span></td>
    <td valign="middle"></td>
    <td align="right" valign="middle" class="chico_bold"><span class="chico">ORIGINAL: COMPRADOR</span></td>
  </tr>
  <tr>
    <td height="12" valign="middle"></td>
    <td valign="middle"></td>
    <td align="right" valign="middle" class="chico_bold"><span class="chico">DUPLICADO: ARCHIVO TRIBUTARIO</span></td>
  </tr>
</table>
</body>
</html>';

v_detalle_01 varchar2(1000) := '<tr bgcolor="#eaeaea" class="item">
    <td height="28" align="right">&CAN &nbsp;</td>
    <td align="right">&CTA&nbsp;</td>
    <td align="right">&REC&nbsp;</td>
    <td align="right">&FEC&nbsp;</td>
    <td align="left">&DES&nbsp;</td>
    <td align="right">&EXE&nbsp;</td>
    <td align="right">&GRA5&nbsp;</td>
    <td align="right">&GRA10&nbsp;</td>
</tr>';

v_detalle_02 varchar2(1000) := '<tr class="item">
    <td height="28" align="right">&CAN &nbsp;</td>
    <td align="right">&CTA&nbsp;</td>
    <td align="right">&REC&nbsp;</td>
    <td align="right">&FEC&nbsp;</td>
    <td align="left">&DES&nbsp;</td>
    <td align="right">&EXE&nbsp;</td>
    <td align="right">&GRA5&nbsp;</td>
    <td align="right">&GRA10&nbsp;</td>
</tr>';

cursor cabecera is
SELECT nro_factura, 
'Timbrado No. '||nro_timbrado nro_timbrado, 
'V&aacute;lido hasta '||fug_des_mes(a.fec_vig_timbrado)||' de '||to_char(a.fec_vig_timbrado,'yyyy') mes_validez,
fecha, 
c.Oficina,
c.oficina||', '||fug_des_fecha(fecha) des_fecha, 
tip_comprobante,
b.significado des_tip_comprobante, 
a.tip_venta tip_venta,
decode(dig_verificador,null,nro_documento,nro_documento||'-'||dig_verificador) nro_ruc,
nom_completo, 
a.direccion,
a.telefono,
mto_exento, 
replace(DECODE(a.cod_moneda,'GS',to_char(nvl(mto_gravado_5_gs,0)+nvl(impuesto_5_gs,0),'999G999G999G999G999'),to_char(nvl(mto_gravado_5,0)+nvl(impuesto_5,0),'999G999G999G999G999D99')),',','.')  mto_gravado_5, 
replace(DECODE(a.cod_moneda,'GS',to_char(nvl(mto_gravado_10_gs,0)+nvl(impuesto_10_gs,0),'999G999G999G999G999'),to_char(nvl(mto_gravado_10,0)+nvl(impuesto_10,0),'999G999G999G999G999D99')),',','.')  mto_gravado_10, 
a.cod_moneda||' '||LTRIM(replace(DECODE(a.cod_moneda,'GS',to_char(nvl(mto_exento_gs,0) + nvl(mto_gravado_5_gs,0) + nvl(mto_gravado_10_gs,0)+nvl(impuesto_5_gs,0)+nvl(impuesto_10_gs,0),'999G999G999G999G999'),
                                 to_char(nvl(mto_exento,0) + nvl(mto_gravado_5,0) + nvl(mto_gravado_10,0)+nvl(impuesto_5,0)+nvl(impuesto_10,0),'999G999G999G999G999D99')),',','.')||'.-')  tot_venta, 
a.cod_moneda||' '||ltrim(replace(DECODE(a.cod_moneda,'GS',to_char(impuesto_5_gs,'999G999G999G999G999'),to_char(impuesto_5,'999G999G999G999G999D99')),',','.'))  impuesto_5, 
a.cod_moneda||' '||ltrim(replace(DECODE(a.cod_moneda,'GS',to_char(impuesto_10_gs,'999G999G999G999G999'),to_char(impuesto_10,'999G999G999G999G999D99')),',','.'))  impuesto_10, 
a.cod_moneda||' '||ltrim(replace(DECOdE(a.cod_moneda,'GS',to_char(nvl(impuesto_5_gs,0) + nvl(impuesto_10_gs,0),'999G999G999G999G999'),
               to_char(nvl(impuesto_5,0) + nvl(impuesto_10,0),'999G999G999G999G999D99')),',','.'))   tot_iva,
decode(a.tip_comprobante,'N','TOTAL A ACREDITAR  ','TOTAL A PAGAR  ')||fue_obt_des_moneda(a.cod_moneda)||' '||
fue_obt_denominacion(decode(a.cod_moneda,'GS',nvl(mto_exento_GS,0) + nvl(mto_gravado_5_GS,0) + nvl(mto_gravado_10_GS,0)+nvl(impuesto_5_GS,0)+nvl(impuesto_10_GS,0),
                            nvl(mto_exento,0) + nvl(mto_gravado_5,0) + nvl(mto_gravado_10,0)+nvl(impuesto_5,0)+nvl(impuesto_10,0)))||'.-' des_tot_venta,
decode(nro_fac_referencia,'0',null,nro_fac_referencia) nro_fac_referencia, 
decode(nro_tim_referencia,'0',null,nro_tim_referencia) nro_tim_referencia, 
decode(impreso,'N','ORIGINAL','COPIA') tip_impresion,
c.nom_entidad,
'RUC ' ||c.ruc_entidad ruc_entidad,
c.matriz,
c.direccion dir_oficina,
c.telefono tel_oficina,
a.cod_moneda,
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
   AND a.nro_factura = v_nro_factura
   AND a.cod_persona = p_cod_persona
order by nro_factura;
-- cursor de detalles
cursor detalles is
select 1 cantidad,
       fue_obt_titulo(a.descripcion) descripcion,
       REPLACE(decode(b.cod_moneda,'GS',
                 TO_CHAR(nvl(a.mto_exento_gs,0) + nvl(a.mto_gra_5_gs,0) + nvl(a.mto_gra_10_gs,0)+nvl(a.impuesto_5_gs,0)+nvl(a.impuesto_10_gs,0),'999G999G999G999G999'),
                 TO_CHAR(nvl(a.mto_exento,0) + nvl(a.mto_gravado_5,0) + nvl(a.mto_gravado_10,0)+nvl(a.impuesto_5,0)+nvl(a.impuesto_10,0),'999G999G999G999G999D99')),',','.') precio,
       REPLACE(decode(b.cod_moneda,'GS',TO_CHAR(a.mto_exento_gs,'999G999G999G999G999'),TO_CHAR(a.mto_exento,'999G999G999G999G999D99')),',','.')  mto_exento,
       REPLACE(DECODE(b.cod_moneda,'GS',TO_CHAR(nvl(a.mto_gra_5_gs,0)+nvl(a.impuesto_5_gs,0),'999G999G999G999G999'),
                                        TO_CHAR(nvl(a.mto_gravado_5,0)+nvl(a.impuesto_5,0),'999G999G999G999G999D99')),',','.')   mto_gra_5,
       REPLACE(DECODE(b.cod_moneda,'GS',TO_CHAR(nvl(a.mto_gra_10_gs,0)+nvl(a.impuesto_10_gs,0),'999G999G999G999G999'),
                                   TO_CHAR(nvl(a.mto_gravado_10,0)+nvl(a.impuesto_10,0),'999G999G999G999G999D99')),',','.')  mto_gra_10 ,
       a.nro_factura,
       a.nro_timbrado,
       to_char(a.fecha,'dd/mm/yy') fec_linea,
       a.nro_documento,
       a.nro_cuenta
from cb_lib_ventas b, cb_lib_ventas_det a
where A.NRO_FACTURA = v_nro_factura
  and b.nro_factura = a.nro_factura
  and b.nro_timbrado = a.nro_timbrado
  and b.cod_persona = p_cod_persona
  --and b.nro_timbrado = fub_obt_nro_timbrado(b.tip_comprobante)
  and to_char(b.fecha, 'yyyymm') = to_char(a.fecha,'yyyymm')
order by a.fecha, a.hora;

v_detalles clob := null;
v_des_periodo varchar2(150);
v_cantidad number := 0;
v_diferencia number := 0;
v_det varchar2(1000);
--v_cod_persona varchar2(20);
  PRAGMA AUTONOMOUS_TRANSACTION; --- para que grabe solo esta transaccion
begin
  --v_cod_persona := fug_obt_cli_principal(p_nro_cuenta);
  if p_nro_factura is null then
    pab_iva.PR_GEN_LIB_VTA_TMP(p_cod_persona);
    v_nro_factura := pab_iva.FU_GEN_FACTURA(p_cod_persona);
  else
    v_nro_factura := trim(p_nro_factura);
  end if;
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
      v_det := replace(v_det,'&FEC',pag_htm.fu_con_html(d.fec_linea));
      v_det := replace(v_det,'&DES',pag_htm.fu_con_html(d.descripcion));
      --v_det := replace(v_det,'&PRE',d.precio);
      v_det := replace(v_det,'&EXE',d.mto_exento);
      v_det := replace(v_det,'&GRA5',d.mto_gra_5);
      v_det := replace(v_det,'&GRA10',d.mto_gra_10);
      v_detalles := v_detalles || v_det;
  end loop;
  --

  if (v_cantidad < 25 and v_cantidad > 0) then
    v_diferencia:= 25 - v_cantidad;

    for d in 1..v_diferencia loop
      v_cantidad := v_cantidad + 1;
      if v_cantidad / 2 = trunc(v_cantidad / 2) then
         v_det := v_detalle_01;
      else
         v_det := v_detalle_02;
      end if;

      v_det := replace(v_det,'&CAN','');
      v_det := replace(v_det,'&REC','');
      v_det := replace(v_det,'&CTA','');
      v_det := replace(v_det,'&FEC','');
      v_det := replace(v_det,'&DES','');
      v_det := replace(v_det,'&EXE','');
      v_det := replace(v_det,'&GRA5','');
      v_det := replace(v_det,'&GRA10','');
      v_detalles := v_detalles || v_det;

    end loop;
  end if;

  select 'de '||to_char(min(n.fecha),'dd')||' al '||to_char(fug_des_fecha(max(n.fecha))) 
    into v_des_periodo
    from cb_lib_ventas_det n
   where n.nro_factura = v_nro_factura;
  --
  v_factura := v_cabecera ||v_detalles|| v_pie;
  for c in cabecera loop
    v_factura := replace(v_factura,'&NRO_FACTURA',c.nro_factura);
    v_factura := replace(v_factura,'&NRO_TIMBRADO',c.nro_timbrado);
    v_factura := replace(v_factura,'&DES_TIP_COMPROBANTE',c.des_tip_comprobante);
    v_factura := replace(v_factura,'&NRO_RUC_ENTIDAD',c.ruc_entidad);
    v_factura := replace(v_factura,'&MES_VAL_TIMBRADO',c.mes_validez);
    v_factura := replace(v_factura,'&NOM_ENTIDAD',pag_htm.fu_con_html(c.nom_entidad));
    v_factura := replace(v_factura,'&DIR_OFICINA',pag_htm.fu_con_html(c.dir_oficina));
    v_factura := replace(v_factura,'&DIR_MATRIZ',pag_htm.fu_con_html(c.matriz));
    v_factura := replace(v_factura,'&FEC_EMISION',pag_htm.fu_con_html(c.des_fecha));
    v_factura := replace(v_factura,'&NRO_DOC_CLIENTE',c.nro_ruc);
    v_factura := replace(v_factura,'&NOM_CLIENTE',pag_htm.fu_con_html(c.nom_completo)||' No.de Cliente: '||p_cod_persona);
    v_factura := replace(v_factura,'&DIR_CLIENTE',pag_htm.fu_con_html(c.direccion));
    v_factura := replace(v_factura,'&TEL_CLIENTE',c.telefono);
    v_factura := replace(v_factura,'&PER_FACTURACION',v_des_periodo);
    v_factura := replace(v_factura,'&TOT_EXENTO',trim(to_char(c.mto_exento)));
    v_factura := replace(v_factura,'&TOT_GRA_5',trim(to_char(c.mto_gravado_5)));
    v_factura := replace(v_factura,'&TOT_GRA_10',trim(to_char(c.mto_gravado_10)));
    v_factura := replace(v_factura,'&MTO_TOTAL',trim(to_char(c.tot_venta)));
    v_factura := replace(v_factura,'&DES_TOTAL',pag_htm.fu_con_html(c.des_tot_venta));
    v_factura := replace(v_factura,'&TOT_IVA_5',trim(to_char(c.impuesto_5)));
    v_factura := replace(v_factura,'&TOT_IVA_10',trim(to_char(c.impuesto_10)));
    v_factura := replace(v_factura,'&TOT_IVA',trim(to_char(c.tot_iva)));
    v_factura := replace(v_factura,'&TIP_IMPRESION',c.tip_impresion);
    if c.tip_venta = 'CR' THEN
       v_factura := replace(v_factura,'&MAR_CONDICION','Cr&eacute;dito');
       --v_factura := replace(v_factura,'&MAR_CREDITO','X');
    else
       v_factura := replace(v_factura,'&MAR_CONDICION','Contado');
       --v_factura := replace(v_factura,'&MAR_CREDITO','');
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
  if v_cantidad =  0 then
    pag_htm.PR_TABLA('S',630,50,0); -- DEFINO LA TABLA
      if v_nro_factura is null then
         pag_htm.PR_FILA('S'); -- ABRO LA FILA
            pag_htm.PR_COLUMNA('Usted  NO  tiene  facturas',NULL,'center','S'); -- agrego la columna etiqueta
         pag_htm.PR_FILA('N'); -- CIERRO LA FILA
         pag_htm.PR_FILA('S'); -- ABRO LA FILA
            pag_htm.PR_COLUMNA('pendientes de ser impresas.',NULL,'center','S'); -- agrego la columna etiqueta
         pag_htm.PR_FILA('N'); -- CIERRO LA FILA         
      else
         pag_htm.PR_COLUMNA('Factura '||v_nro_factura||' ya fue impresa.',NULL,'center','S'); -- agrego la columna etiqueta
      end if;   
    pag_htm.PR_TABLA('N'); -- CIERRO LA TABLA 
    return pag_htm.v_texto;
  else
      v_factura:=replace(v_factura,chr(10),'');
      v_factura:=replace(v_factura,chr(13),'');
      return v_factura;
     
  end if;
end;
/

