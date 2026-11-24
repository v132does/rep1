CREATE OR REPLACE PROCEDURE IT.PRG_ELI_EXTRACTOS_TMP
 IS
 /* Elimina las tablas de extractos a requerimiento. Se corre diariamente en el cierre */
  V_MSJ VARCHAR2(1000);
begin
    --eliminar tablas de extractos a requerimiento
    sql_util.ejecute_dml('TRUNCATE TABLE GE_EXT_RESUMENES_TMP', v_msj);
    if v_msj is not null then
        raise_application_error(-20000, v_msj);
    end if;
    sql_util.ejecute_dml('TRUNCATE TABLE GE_EXT_CLI_MOV_RETENIDOS_TMP', v_msj);
    if v_msj is not null then
        raise_application_error(-20000, v_msj);
    end if;
    sql_util.ejecute_dml('TRUNCATE TABLE GE_EXT_CLI_MOVIMIENTOS_TMP', v_msj);
    if v_msj is not null then
        raise_application_error(-20000, v_msj);
    end if;
    sql_util.ejecute_dml('TRUNCATE TABLE GE_EXT_CLI_CUENTAS_TMP', v_msj);
    if v_msj is not null then
        raise_application_error(-20000, v_msj);
    end if;
    sql_util.ejecute_dml('TRUNCATE TABLE GE_EXT_CLIENTES_TMP', v_msj);
    if v_msj is not null then
        raise_application_error(-20000, v_msj);
    end if;
end;
/

