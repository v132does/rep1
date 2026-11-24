CREATE OR REPLACE FUNCTION IT.fug_obt_usu_xad_sipap RETURN varchar2 IS
  /*Para obtener el Usuario X-Adapter DEPO para cabecera de archivos*/
  --Variables--
  v_bas_produccion   ge_par_dinamicos.val_parametro%type;
  v_bas_conectada    ge_par_dinamicos.val_parametro%type;
  v_usu_xadapter     varchar2(12);
BEGIN
  --Verificacion de Base de Datos--
  v_bas_produccion := fug_obt_pardinamico('BD_PROD');
  SELECT upper(sys_context('USERENV', 'DB_NAME'))
    INTO v_bas_conectada
    FROM dual;
  IF v_bas_produccion = v_bas_conectada then
     v_usu_xadapter := fug_obt_pardinamico( 'SNP_USU_XADAPTER' );
  else
     v_usu_xadapter := fug_obt_pardinamico('SNP_USU_XAD_DESA');
  end if;
  return v_usu_xadapter;

exception
  when others then
       raise_application_error(-20000,'Error en fug_obt_usu_xad_sipap: '||sqlerrm);
end;
/

