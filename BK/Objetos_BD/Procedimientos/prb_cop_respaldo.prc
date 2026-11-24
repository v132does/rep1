CREATE OR REPLACE PROCEDURE IT.PRB_COP_RESPALDO
 IS
 v_msj  varchar2(250);
BEGIN
    /* elimino los datos de las copias de seguridad */
    v_msj := null;
    sql_util.ejecute_dml('TRUNCATE TABLE cb_sal_oficinas_res DROP STORAGE', v_msj);
    if v_msj is not null then
       raise_application_error(-20001, v_msj);
    end if;
    v_msj := null;
    sql_util.ejecute_dml('TRUNCATE TABLE cb_sal_consolidados_res DROP STORAGE', v_msj);
    if v_msj is not null then
       raise_application_error(-20002, v_msj);
    end if;
    v_msj := null;
    sql_util.ejecute_dml('TRUNCATE TABLE cb_asientos_det_res DROP STORAGE', v_msj);
    if v_msj is not null then
       raise_application_error(-20003, v_msj);
    end if;
    v_msj := null;
    sql_util.ejecute_dml('TRUNCATE TABLE cb_asientos_res DROP STORAGE', v_msj);
    if v_msj is not null then
       raise_application_error(-20004, v_msj);
    end if;
    -- Fecha: 28/08/2013 (DI).
    -- Requerimiento: REG-BBVA-0027-ETRA-DSIS-02-FATD.01-ASI_MAN_NIV_CLIENTE.docx
    -- Elimino los registros de la tabla de respaldo de los datos adicionales de los asientos manuales.
    v_msj := null;
    sql_util.ejecute_dml('TRUNCATE TABLE cb_dat_asientos_det_res DROP STORAGE', v_msj);
    if v_msj is not null then
       raise_application_error(-20004, v_msj);
    end if;
    /* Inicializar variable global del modulo para traer la cotizacion de contabilidad */
    pae_cnf.G_COD_MODULO := 2;
    /* inserto los registros de copia */
    insert into cb_sal_oficinas_res select * from cb_sal_oficinas;
    insert into cb_sal_consolidados_res select * from cb_sal_consolidados;
    insert into cb_asientos_det_res select * from cb_asientos_det;
    insert into cb_asientos_res      select * from cb_asientos;
    -- Fecha: 28/08/2013 (DI).
    -- Requerimiento: REG-BBVA-0027-ETRA-DSIS-02-FATD.01-ASI_MAN_NIV_CLIENTE.docx
    -- Realizo la copia de respaldo de los datos adicionales de los asientos manuales.
    insert into cb_dat_asientos_det_res select * from cb_dat_asientos_det;
END;
/

