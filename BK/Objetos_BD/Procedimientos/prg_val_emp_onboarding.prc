create or replace procedure it.prg_val_emp_onboarding(p_nro_documento_soli in ba_personas.nro_documento%type,
                                                      p_onb_permite        out varchar2,
                                                      p_cod_error          out number,
                                                      p_mensaje            out varchar2) is
  v_det_error    varchar2(4000);
  v_cod_per_soli ba_personas.cod_persona%type;

begin
  p_onb_permite := 'S';

  IF p_nro_documento_soli IS NULL THEN
    p_cod_error := 1;
    p_mensaje   := 'La persona no puede ser nula';
    RETURN;
  END IF;

  begin
    select cod_persona
      into v_cod_per_soli
      from ba_personas
     where cod_tip_documento = '1'
       and nro_documento = p_nro_documento_soli;
  exception
    when no_data_found then
      p_onb_permite := 'S';
      p_cod_error   := 1;
   --   p_mensaje     := 'La persona no puede ser nula';
    when others then
      p_onb_permite := 'S';
      v_det_error   := substr('Ocurrió un error durante la consulta' ||sqlerrm,1,4000);
      p_cod_error   := 2;
      p_mensaje     := 'Ocurrió un error durante la consulta';
  end;


 if nvl(p_cod_error, 0) = 0 then

    /*Verifico que no exista el registro de las parametricas ya creado*/
    if nvl(fue_obt_onb_dat_adicional(v_cod_per_soli, 'CAN_REG_ONB_EMPRESA'),'N') = 'N'
       and nvl(fue_obt_onb_dat_adicional(v_cod_per_soli,'MAX_REG_SOL_ONB_EMPRESA'),'N') = 'N' then
            p_onb_permite := 'S';
    end if;
    /*Si existe el registro de las parametricas, se debe verificar el valor de dichas parametricas*/
    if nvl(fue_obt_onb_dat_adicional(v_cod_per_soli, 'CAN_REG_ONB_EMPRESA'),'N') = 'S'
      and nvl(fue_obt_onb_dat_adicional(v_cod_per_soli,'MAX_REG_SOL_ONB_EMPRESA'),'N') = 'S' then

      -- Verifico el valor del campo val_parametro
      if nvl(fue_per_dat_adicional(v_cod_per_soli, 'CAN_REG_ONB_EMPRESA'),'0') <
         nvl(fue_per_dat_adicional(v_cod_per_soli, 'MAX_REG_SOL_ONB_EMPRESA'),'0') then
             p_onb_permite := 'S';
      end if;
      if nvl(fue_per_dat_adicional(v_cod_per_soli, 'CAN_REG_ONB_EMPRESA'), '0') >=
         nvl(fue_per_dat_adicional(v_cod_per_soli, 'MAX_REG_SOL_ONB_EMPRESA'),'0') THEN
             p_onb_permite := 'N';
      end if;
    end if;

  end if;

  if nvl(p_cod_error, 0) != 0 then
    it.prg_ins_log_programas('PRG_VAL_EMP_ONBOARDING',substr(p_cod_error || ' - ' || v_det_error,1,4000),null);
  else
    p_cod_error := 0;
    p_mensaje   := null;
  end if;

exception
  when others then
    p_onb_permite := 'N';
    p_cod_error   := 999;
    p_mensaje     := 'Ocurrió un error inesperado';
    v_det_error   := substr('Ocurrió un error inesperado' || sqlerrm,1,4000);
    it.prg_ins_log_programas('PRG_VAL_EMP_ONBOARDING',substr(p_cod_error || ' - ' || v_det_error,1,4000),null);

end prg_val_emp_onboarding;
/

