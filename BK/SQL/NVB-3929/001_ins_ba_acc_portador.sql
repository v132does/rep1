DECLARE
  v_err        varchar2(4000);
  v_comentario varchar2(4000);
  CURSOR c_acc IS
    SELECT a.*
      FROM ba_per_sociedades@uenodesg a
     where exists (select 1
                    from it.ba_per_juridicas j
                   where a.cod_persona = j.cod_persona)
        and not exists (select 1 
                          from it.ba_acc_portador p 
                          where a.cod_persona = p.cod_persona);
  /*COD_PERSONA
  COD_MONEDA
  TIP_ACCION
  CAN_ACC_PORTADOR
  MTO_CAP_SUSCRITO
  MTO_CAP_INTEGRADO
  MTO_NOM_ACCION
  ESTADO
  CAN_ACC_NOMINATIVA
  */
BEGIN
  BEGIN
    pre_ini_aplicacion;
  END;
   --desabilitar los triggers
  sql_util.ejecute_dml('alter table it.ba_acc_portador disable all triggers',
                       v_err);
  if v_err is not null then
    v_comentario := 'Al desabilitar trigger TABLA IT.ba_acc_portador' ||
                    v_err;
    dbms_output.put_line(v_comentario);
  end if;
   --
  FOR a IN c_acc LOOP
    update it.ba_acc_portador j
       set j.ind_acc_portador   = a.tip_accion,
           j.cod_moneda         = a.cod_moneda,
           j.cap_suscrito       = a.mto_cap_suscrito,
           j.cap_integrado      = a.mto_cap_integrado,
           j.can_acc_portador   = a.can_acc_portador,
           j.can_acc_nominativa = a.can_acc_nominativa
     where j.cod_persona = a.cod_persona;

    IF SQL%NOTFOUND THEN
      insert into it.ba_acc_portador
        (cod_persona,
         ind_acc_portador,
         cod_moneda,
         cap_suscrito,
         cap_integrado,
         can_acc_portador,
         can_acc_nominativa,
         usu_insercion,
         fec_insercion,
         usu_modificacion,
         fec_modificacion)
      values
        (a.cod_persona,
         a.tip_accion,
         a.cod_moneda,
         a.mto_cap_suscrito,
         a.mto_cap_integrado,
         a.can_acc_portador,
         a.can_acc_nominativa,
         'MIGRA',
         SYSDATE,
         'MIGRA',
         SYSDATE);
    END IF;
  END LOOP;
  --habilitamos los triggers de ge_causales
  sql_util.ejecute_dml('alter table it.ba_acc_portador enable all triggers',
                       v_err);
  if v_err is not null then
    v_comentario := 'Al habilitar trigger TABLA IT.ba_acc_portador' ||
                    v_err;
    dbms_output.put_line(v_comentario);
  end if;
  ------
exception
  when others then
    raise_application_error(-20000,
                            'Error en el proceso de insercion: ' || '-' ||
                            sqlerrm);
end;
