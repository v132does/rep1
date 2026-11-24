CREATE OR REPLACE PROCEDURE IT.PRB_TRA_ASI_HISTORICO IS
 /* transferencia de asientos al historico y borrado */
w_cuantos       NUMBER;
v_msj           varchar2(4000);
v_min_fec_valor date;
v_ayer          date;
v_nro_inicio  number;
v_nro_asiento number;
v_max_nro_asi number := 0;

cursor asi is 
  select *
    from cb_asientos_his
   where fecha >= v_min_fec_valor
   order by fec_valor, nro_asiento
     for update of nro_asiento;
     
cursor c_duplicados is
select a.fecha, a.cod_oficina, a.nro_asiento
  from CB_ASIENTOS a
 where a.ACTUALIZADO = 'S'
   and exists (select 1 from CB_ASIENTOS_HIS b
                where a.FECHA = b.fecha
                  and a.COD_OFICINA = b.cod_oficina
                  and a.NRO_ASIENTO = b.nro_asiento);
   
BEGIN
  --obtener la fecha de ayer ya q previamente se cambió la fecha calendario
  v_ayer := pag_cal.FU_OBT_FEC_ANT_HAB(pag_cal.FU_OBT_FEC_ACTUAL(2), 1);
  --buscar la mínima fecha valor de asientos
  select min(fecha) 
    into v_min_fec_valor
    from cb_asientos;
  --buscar el mínimo nro de asiento para la mínima fecha valor, del histórico
  select min(nro_asiento)  
    into v_nro_inicio
    from cb_asientos_his
   where fecha = v_min_fec_valor;

  if v_min_fec_valor is null then
     RAISE_APPLICATION_ERROR(-20000,'No se encontraron asientos para transferir ');
  ELSE
     -- Proceso cierre ejercicio GNB Fusion
     -- Inicio ejercicio GNB py
     select count(*)
       into w_cuantos
       from CB_ASIENTOS a
      where a.ACTUALIZADO = 'S'
        and exists (select 1 from CB_ASIENTOS_HIS b
                     where a.FECHA = b.fecha
                       and a.COD_OFICINA = b.cod_oficina
                       and a.NRO_ASIENTO = b.nro_asiento);
     if nvl(w_cuantos,0) > 0 then
        select max(nro_asiento)
          into v_max_nro_asi
          from CB_ASIENTOS;
        for i in c_duplicados loop
           insert into CB_ASIENTOS (
                  fecha, cod_oficina, nro_asiento, cod_usuario,
                  cod_modulo, cod_modalidad, tot_control, actualizado,
                  reversado, ofi_integrada, confirmado, cod_ofi_origen,
                  fec_valor, nro_asi_automatico, nro_asi_futuro, cod_cargo)
           select fecha, cod_oficina, (nro_asiento + nvl(v_max_nro_asi,0)), cod_usuario,
                  cod_modulo, cod_modalidad, tot_control, actualizado,
                  reversado, ofi_integrada, confirmado, cod_ofi_origen,
                  fec_valor, nro_asi_automatico, nro_asi_futuro, cod_cargo
             from CB_ASIENTOS a
            where a.FECHA = i.fecha
              and a.COD_OFICINA = i.cod_oficina
              and a.NRO_ASIENTO = i.nro_asiento;
           
           update CB_ASIENTOS_DET a
              set a.nro_asiento = nro_asiento + nvl(v_max_nro_asi,0)
            where a.FECHA = i.fecha
              and a.COD_OFICINA = i.cod_oficina
              and a.NRO_ASIENTO = i.nro_asiento;
           
           delete CB_ASIENTOS a
            where a.FECHA = i.fecha
              and a.COD_OFICINA = i.cod_oficina
              and a.NRO_ASIENTO = i.nro_asiento;
        end loop;
     end if;
     -- mueve los asientos al histórico
     insert into CB_ASIENTOS_HIS     select * from CB_ASIENTOS     where ACTUALIZADO = 'S';
     insert into CB_ASIENTOS_DET_HIS select * from CB_ASIENTOS_DET where ACTUALIZADO = 'S';
     -- Fecha: 28/08/2013 (DI).
     -- Requerimiento: REG-BBVA-0027-ETRA-DSIS-02-FATD.01-ASI_MAN_NIV_CLIENTE.docx
     -- Inserto los datos adicionales de asientos manuales en el histórico.
     INSERT INTO cb_dat_asientos_det_his SELECT cb.* FROM cb_dat_asientos_det cb, cb_asientos ca WHERE cb.nro_asiento = ca.nro_asiento AND ca.actualizado = 'S';

     v_nro_asiento := v_nro_inicio;
     --reenumerar asientos si hubo fecha valor
     if v_min_fec_valor < v_ayer then
        --recorrer los asientos por todas las fechas desde la mínima fecha valor hasta ayer
        for reg in asi loop
          --actualizar nros de asientos en histórico detalles
          update cb_asientos_det_his
             set nro_asiento = v_nro_asiento
           where fecha = reg.fecha
             and cod_oficina = reg.cod_oficina
             and nro_asiento = reg.nro_asiento;
          --actualizar nros de asientos en histórico cabecera   
          update cb_asientos_his
             set nro_asiento = v_nro_asiento
           where current of asi;  
          -- Fecha: 28/08/2013 (DI).
          -- Requerimiento: REG-BBVA-0027-ETRA-DSIS-02-FATD.01-ASI_MAN_NIV_CLIENTE.docx
          -- Actualizo el nro. de asiento de los datos adicionales.
          IF reg.nro_asi_automatico IS NULL AND reg.nro_asi_futuro IS NULL THEN
             UPDATE cb_dat_asientos_det_his
                SET nro_asiento = v_nro_asiento
              WHERE fecha = reg.fecha
                AND cod_oficina = reg.cod_oficina
                AND nro_asiento = reg.nro_asiento;
          END IF;        
          --incrementar nro de asiento
          v_nro_asiento := v_nro_asiento + 1;
        end loop;
     end if;
     
     -- Borro tablas de asientos
     v_msj := null;
     --- OBS: No puede ser con sql_util porque hace el commit y no puede reprocesarse
     /*sql_util.ejecute_dml('TRUNCATE TABLE CB_ASIENTOS_DET', v_msj);
     if v_msj is not null then
         raise_application_error(-20000, v_msj);
     end if;
     --
     v_msj := null;
     sql_util.ejecute_dml('TRUNCATE TABLE CB_ASIENTOS', v_msj);
     if v_msj is not null then
         raise_application_error(-20000, v_msj);
     end if;*/
     -- Fecha: 28/08/2013 (DI).
     -- Requerimiento: REG-BBVA-0027-ETRA-DSIS-02-FATD.01-ASI_MAN_NIV_CLIENTE.docx
     -- Elimino los asientos del día.
     delete cb_dat_asientos_det;
     delete cb_asientos_det;
     delete cb_asientos;
  END IF;
EXCEPTION
   WHEN OTHERS then
     IF sqlcode <= -20000 THEN
       raise;
     ELSE
       RAISE_APPLICATION_ERROR(-20000,'Error al transferir asientos '||sQLERRM);
     END IF;
END;
/

