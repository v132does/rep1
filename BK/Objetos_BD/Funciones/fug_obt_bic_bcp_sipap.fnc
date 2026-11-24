CREATE OR REPLACE FUNCTION IT.fug_obt_bic_bcp_sipap RETURN varchar2 IS
  /*Para obtener el BIC de DEPO para cabecera de archivos*/
  --Variables--
  v_bas_produccion   ge_par_dinamicos.val_parametro%type;
  v_bas_conectada    ge_par_dinamicos.val_parametro%type;
  v_bic_bcp_swift    varchar2(12);
BEGIN
  --Verificacion de Base de Datos--
  v_bas_produccion := fug_obt_pardinamico('BD_PROD');
  SELECT upper(sys_context('USERENV', 'DB_NAME'))
    INTO v_bas_conectada
    FROM dual;
  IF v_bas_produccion = v_bas_conectada then
     v_bic_bcp_swift := fug_obt_pardinamico('SNP_AUT_BIC_BCP_OPE');
  else
     v_bic_bcp_swift := fug_obt_pardinamico('SNP_AUT_BIC_DES_OPE');
  end if;
  return v_bic_bcp_swift;

exception
  when others then
       raise_application_error(-20000,'Error en fug_obt_bic_bcp_sipap: '||sqlerrm);
end;
/

