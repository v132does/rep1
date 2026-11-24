CREATE OR REPLACE PROCEDURE IT.PRG_ENV_OPE_PENDIENTES /*(V_FECHA := fug_obt_fec_actual(1) in DATE)*/
 IS

  v_texto_usu       clob;
  v_texto_jefe      clob;
  v_cabecera        clob;
  v_dir_correo      ba_personas.dir_correo%type := fug_obt_dir_correo;
  v_dir_correo_usu  ba_personas.dir_correo%type;
  v_dir_correo_jefe ba_personas.dir_correo%type;

  cursor cabecera is
    select cod_usuario
      from gv_cie_previo a
     group by cod_usuario
     order by cod_usuario;

  cursor detalle(v_usuario char) is
    select a.tipo,
           a.estado,
           to_char(TRUNC(FECHA),'dd/mm/yyyy') fecha,
           a.hora,
           a.usuario,
           a.cod_usuario,
           a.ofi_ori,
           a.caja,
           a.tran,
           a.ofi,
           a.referencia,
           a.cod_moneda,
           a.monto,
           a.CONCEPTO,
           a.tabla,
           a.nro_documento
      from gv_cie_previo a
     where a.cod_usuario = v_usuario
     order by a.cod_usuario, a.hora;

begin
  v_dir_correo      := fug_obt_dir_correo;
  v_dir_correo_jefe := fug_obt_pardinamico('EMAIL_ENV_CIE_PREVIO');
  
  v_cabecera :=  'FECHA     ' || CHR(9) || 'HORA    ' || CHR(9) ||
                   'USUARIO        ' || CHR(9) || 'ESTADO               ' ||
                   CHR(9) || 'COD_MONEDA' || CHR(9) || 'MONTO' || CHR(9) ||
                   'NRO_DOCUMENTO' || CHR(9) || 'OFI_ORI' || CHR(9) ||
                   'OFI' || CHR(9) || 'CAJA' || CHR(9) || 'TRAN' || CHR(9) ||
                   'REFERENCIA' || CHR(9) || 'CONCEPTO' || CHR(13) ||
                   CHR(10);
   
  for C in cabecera loop
   v_texto_jefe := v_texto_jefe || v_texto_usu;
   v_texto_usu := null;
    for k in detalle(c.cod_usuario) loop
    
      v_texto_usu := v_texto_usu || k.fecha || chr(9) || k.hora || chr(9) ||
                     k.cod_usuario || '-' || k.usuario || chr(9) ||
                     k.estado || chr(9) || k.cod_moneda || chr(9) ||
                     k.monto || chr(9) || k.nro_documento || chr(9) ||
                     k.ofi_ori || chr(9) || k.ofi || chr(9) || k.caja ||
                     chr(9) || k.tran || chr(9) || k.referencia || chr(9) ||
                     k.concepto || chr(13) || chr(10);
    
      
    
    end loop;
    it_mail.mail_attach_XLS(v_dir_correo,
                        fug_obt_dir_mail_usu(c.COD_usuario),
                        'Verificacion Previa al cierre_'||to_char(TRUNC(sysdate),'dd/mm/yyyy'),
                        'Control de Operaciones COMEX pendientes'||sysdate,
                        v_cabecera||v_texto_usu,
                        'CIE_PREVIO_' || c.COD_usuario||'_'||to_char(TRUNC(sysdate),'dd/mm/yyyy')||'.xls');
  
  end loop;
  -----
  v_texto_jefe := v_texto_jefe || v_texto_usu;
  it_mail.mail_attach_xls(v_dir_correo,
                      V_DIR_CORREO_JEFE,
                       'Verificacion Previa al cierre_'||to_char(TRUNC(sysdate),'dd/mm/yyyy'),
                      'Control de Operaciones COMEX pendientes_'||sysdate,
                      v_cabecera||v_texto_jefe,
                      'CIE_PREVIO_'||to_char(TRUNC(sysdate),'dd/mm/yyyy')||'.xls');

end;
/

