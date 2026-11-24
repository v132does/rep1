CREATE OR REPLACE TRIGGER IT.ta_pr_pre_aprobados
  AFTER DELETE OR INSERT OR UPDATE ON "IT"."PR_PRE_APROBADOS"
  FOR EACH ROW
DECLARE
  v_nro_sms   it.ba_env_sms.nro_sms%TYPE := NULL;
  v_texto_sms it.ba_env_sms.texto_sms%TYPE := NULL;
  v_cel_dest  it.ba_env_sms.cel_destinatario%TYPE := NULL;
  v_men_error varchar2(4000);
  v_cod_err   number(6);
  v_nro_sol   number;
  --BWP-16 - glopez subprograma que retorna true si ya existe el registro
  function lf_existe_pre(p_lote        pr_pre_aprobados.cod_pre_aprobado%type,
                         p_cod_persona pr_pre_aprobados.cod_persona%type)
    return boolean is
    v_existe varchar2(1) := 'N';
  begin
    select 'S'
      into v_existe
      from ge_pro_pre_aprobados d
     where d.lote = p_lote
       and d.cod_persona = p_cod_persona;
    return(v_existe = 'S'); --Retorna true si se cumple la condicion
  exception
    when too_many_rows then
      return true;
    when others then
      return false;
  end lf_existe_pre;

  /*
      Utilizamos este metodo de inserccion por si algun dia se debe encryptar.
      BWP-16
  */
  procedure lp_ins_praprobado(r_apro ge_pro_pre_aprobados%rowtype) is
  
  begin
    insert into ge_pro_pre_aprobados
      (cod_persona,
       lote,
       cod_oficina,
       plz_12_meses,
       cod_modulo,
       cod_modalidad,
       min_monto,
       max_monto,
       min_plazo,
       max_plazo,
       ind_hab_hb,
       nro_secuencia,
       estado)
    values
      (r_apro.cod_persona,
       r_apro.lote,
       r_apro.cod_oficina,
       r_apro.plz_12_meses,
       r_apro.cod_modulo,
       r_apro.cod_modalidad,
       r_apro.min_monto,
       r_apro.max_monto,
       r_apro.min_plazo,
       r_apro.max_plazo,
       r_apro.ind_hab_hb,
       r_apro.nro_secuencia,
       r_apro.estado);
  end;
BEGIN
  IF inserting THEN
    BEGIN
      it.prg_env_sms(:new.cod_persona,
                     :new.cod_modalidad,
                     v_cod_err,
                     v_men_error);
    EXCEPTION
      WHEN OTHERS then
        raise_application_error(-20006,
                                'Error al insertar en la tabla ba_env_sms ' ||
                                SQLERRM);
    END;
    /*
       BWP-16 - glopez
       Bloque para insertar el pre-aprobado en la tabla de bankiti
    */
    declare
      r_pre ge_pro_pre_aprobados%rowtype;
    begin
    
      --Primero verificamos si ya se inserto
      if not (lf_existe_pre(:new.cod_pre_aprobado, :new.cod_persona)) and
         nvl(:new.estado, 'N') = 'C' and
         nvl(fug_obt_pardinamico('PRE_OFE_PRE_APR_WEB'), 'N') = 'S' then
        --Controlamos el estado
        -- se utiliza para buscar su registro en la tabla PR_PRE_APROBADOS
        r_pre.cod_persona := :new.cod_persona;
        r_pre.lote        := :new.cod_pre_aprobado;
        ---------
        r_pre.cod_oficina   := :new.cod_oficina;
        r_pre.plz_12_meses  := :new.mon_pre_aprobado;
        r_pre.cod_modulo    := 6;
        r_pre.cod_modalidad := :new.cod_modalidad;
        --Para este caso el monto min y max debe ser igual a la mon_pre_aprobado.
        r_pre.min_monto  := :new.mon_pre_aprobado;
        r_pre.max_monto  := :new.mon_pre_aprobado;
        r_pre.min_plazo  := :new.can_cuota;
        r_pre.max_plazo  := :new.can_cuota;
        r_pre.ind_hab_hb := 'S';
        r_pre.estado     := 'V';
        --Para este caso siempre es uno. Fijarse en la pk de la tabla ge_pro_pre_aprobados
        --Siempre sera diferente por que cada ves que le llamemos vamos a insertar cod_pre_aprobado diferente
        r_pre.nro_secuencia := 1;
        lp_ins_praprobado(R_pre);
      end if;
    end;
  END IF;
  /*
      BWP-16 - glopez
      Para el caso de upd de estado
  */
  if updating then
    IF :new.estado not in ('C', 'G') and
       nvl(fug_obt_pardinamico('PRE_OFE_PRE_APR_WEB'), 'N') = 'S' then
      --si es distinto a C=Vigente  - G=En proceso
      v_nro_sol := :new.nro_solicitud;
      begin
        update ge_pro_pre_aprobados d
           set d.estado        = decode(:new.estado, 'D', 'V', 'C'), -- Cancelamos el registro
               d.nro_solicitud = :new.nro_solicitud
         where d.cod_persona = :new.cod_persona
           and d.lote = :new.cod_pre_aprobado
           and d.cod_modulo = 6 --Por defecto
           and d.cod_modalidad = :new.cod_modalidad
           and d.nro_secuencia = 1; --por defecto
      end;
    END IF;
    /*Se agrega por que existe la pantalla donde
    se puede actualizar monto y cuota
    */
    IF (:new.mon_pre_aprobado != :old.mon_pre_aprobado or
       :new.can_cuota != :old.can_cuota) and
       nvl(fug_obt_pardinamico('PRE_OFE_PRE_APR_WEB'), 'N') = 'S' THEN
      begin
        update ge_pro_pre_aprobados d
           set d.min_monto    = :new.mon_pre_aprobado,
               d.max_monto    = :new.mon_pre_aprobado,
               d.plz_12_meses = :new.mon_pre_aprobado,
               d.min_plazo    = :new.can_cuota,
               d.max_plazo    = :new.can_cuota
         where d.cod_persona = :new.cod_persona
           and d.lote = :new.cod_pre_aprobado
           and d.cod_modulo = 6 --Por defecto
           and d.cod_modalidad = :new.cod_modalidad
           and d.nro_secuencia = 1; --por defecto
      end;
    END IF;   
  END IF;

END;
/

