CREATE OR REPLACE PROCEDURE IT.PRB_REAPERTURA
 IS
 v_msj  varchar2(250);
 v_nro_asiento cb_asientos.nro_asiento%type;
 v_fec_actual     date      := pag_cal.fu_obt_fec_actual(2);
 v_fec_anterior date := fug_obt_fec_anterior(2);
BEGIN
    /* elimino los datos de las tablas originales */
    v_msj := null;
    sql_util.ejecute_dml('TRUNCATE TABLE cb_sal_consolidados DROP STORAGE', v_msj);
    if v_msj is not null then
       raise_application_error(-20001, v_msj);
    end if;
    v_msj := null;
    sql_util.ejecute_dml('TRUNCATE TABLE cb_sal_oficinas DROP STORAGE', v_msj);
    if v_msj is not null then
       raise_application_error(-20002, v_msj);
    end if;
    v_msj := null;
    sql_util.ejecute_dml('TRUNCATE TABLE cb_asientos_det DROP STORAGE', v_msj);
    if v_msj is not null then
       raise_application_error(-20003, v_msj);
    end if;
    -- Fecha: 28/08/2013 (DI).
    -- Requerimiento: REG-BBVA-0027-ETRA-DSIS-02-FATD.01-ASI_MAN_NIV_CLIENTE.docx
    -- Elimino los registros de los datos adicionales de los asientos manuales.
    v_msj := null;
    sql_util.ejecute_dml('TRUNCATE TABLE cb_dat_asientos_det DROP STORAGE', v_msj);
    if v_msj is not null then
       raise_application_error(-20003, v_msj);
    end if;
    /*sql_util.ejecute_dml('TRUNCATE TABLE cb_asientos DROP STORAGE', v_msj);
    if v_msj is not null then
       raise_application_error(-20004, v_msj);
    end if;*/
    delete cb_asientos;
    /* restauro las tablas originales */
    insert into cb_sal_oficinas select * from cb_sal_oficinas_res;
    insert into cb_sal_consolidados select * from cb_sal_consolidados_res;
    insert into cb_asientos      select * from cb_asientos_res;
    insert into cb_asientos_det select * from cb_asientos_det_res;
    -- Fecha: 28/08/2013 (DI).
    -- Requerimiento: REG-BBVA-0027-ETRA-DSIS-02-FATD.01-ASI_MAN_NIV_CLIENTE.docx
    -- Inserto los registro de los datos adicionales de los asientos manuales.
    insert into cb_dat_asientos_det select * from cb_dat_asientos_det_res;
    --Obtener el ultimo numero de asiento y actualizar el parametro
    select max(nro_asiento)
      into v_nro_asiento
      from cb_asientos;
    if v_nro_asiento is null then
       --if to_char(v_fec_actual,'yyyymm') = to_char(v_fec_anterior,'yyyymm') then
          select max(nro_asiento)
            into v_nro_asiento
            from cb_asientos_his x
           where x.fecha = v_fec_anterior;
       /*else
          v_nro_asiento := 0;
       end if;*/                   
    end if;

    prg_act_par_dinamico('SIG_NRO_ASIENTO',NULL,NULL,NULL,NULL,(NVL(v_nro_asiento,0) + 1));
    --Actualizar asientos automaticos, inicializar el nro de asiento real asignado
    update cb_asi_automaticos set nro_asi_real = null
     where fecha = v_fec_actual;
    --Actualizar asientos fecha futura, inicializar el nro de asiento real asignado
    update cb_asi_futuros set nro_asi_real = null
     where fecha = v_fec_actual;
    -- cambiar el estado del modulo
    prb_abr_contabilidad;
    -- Inicializar fin de dia
    prb_ini_pro_contab(320);

END;

 

 
/
