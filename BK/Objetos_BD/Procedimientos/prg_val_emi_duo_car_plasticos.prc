create or replace procedure it.prg_val_emi_duo_car_plasticos(p_cod_persona in ba_personas.cod_persona%type,
                                                             p_pla_gratis  out varchar2,
                                                             p_motivo      out varchar2) is
v_cod_error number(1):=0;
v_det_error varchar2(4000);
begin

  begin
    select 'S'
      into p_pla_gratis
      FROM ah_cta_vistas ah, ge_cta_clientes c
     WHERE ah.cod_modalidad in (31, 334)
       and ah.cod_canal=26
       and c.cod_persona = p_cod_persona
       and c.nro_cuenta = ah.nro_cuenta
       and c.relacion = 'P'
       and ah.estado!='C';
      
  exception
    when no_data_found then
      p_pla_gratis := 'N';
      p_motivo := 'Intentá¡ nuevamente luego de que se habilite tu caja de ahorro.';
    when too_many_rows then
       p_pla_gratis := 'S';
    when others then
       p_pla_gratis := 'N';
       p_motivo:='Ocurrió un error durante el proceso de verificación';
       v_det_error:=substr('Ocurrió un error durante el proceso de verificación'||sqlerrm,1,4000);
       v_cod_error:=1;
  end;
  if nvl(p_pla_gratis, 'N') = 'S' then
    begin
      select 'S'
        into p_pla_gratis
        FROM ah_cta_vistas ah, ah_tar_debitos td
       WHERE ah.nro_cuenta = td.nro_cuenta
         and td.cod_persona = p_cod_persona
         and ah.cod_modalidad in (31, 334)
         and ah.estado!='C'
         and ah.cod_canal=26
         and not exists (select 'x'
                from ah_tar_debitos d
               where d.nro_cuenta = td.nro_cuenta
                 and d.cod_persona = td.cod_persona
                 and d.tip_tar_debito = 'MF');
    exception
      when no_data_found then
        p_pla_gratis := 'N';
        p_motivo := 'Verificamos que ya retiraste una duocard.';
      when too_many_rows then
       p_pla_gratis := 'S';
      when others then
        p_pla_gratis := 'N';
        p_motivo:='Ocurrió un error durante el proceso de verificación';
        v_det_error:=substr('Ocurrió un error durante el proceso de verificación'||sqlerrm,1,4000);
        v_cod_error:=2;
    end;
  end if;  
  
    if nvl(p_pla_gratis, 'N') = 'S' then
    begin
      select 'N'
        into p_pla_gratis
        FROM it.ba_per_duocard_registro duo
       WHERE cod_persona = p_cod_persona
       and duo.estado!='C';
       
      p_motivo := 'Verificamos que ya solicitaste o retiraste tu primera duocard.';
    exception
      when no_data_found then
        p_pla_gratis := 'S';
      when too_many_rows then
        p_pla_gratis:='N';
        p_motivo := 'Verificamos que ya solicitaste o retiraste tu primera duocard.';
      when others then
        p_pla_gratis := 'N';
        p_motivo:='Ocurrió un error durante el proceso de verificación';
        v_det_error:=substr('Ocurrió un error durante el proceso de verificación'||sqlerrm,1,4000);
        v_cod_error:=3;
    end;
  end if;
  
   if nvl(v_cod_error,0)!=0 then
     it.prg_ins_log_programas('PRG_VAL_EMI_DUO_CAR_PLASTICOS',substr(v_cod_error||' - '||v_det_error,1,4000),p_cod_persona);
   end if;
    
exception
  when others then
    p_pla_gratis := 'N';
    p_motivo:='Ocurrió un error inesperado';
    v_det_error:=substr('Ocurrió un error inesperado'||sqlerrm,1,4000);
    v_cod_error:=999;
    it.prg_ins_log_programas('PRG_VAL_EMI_DUO_CAR_PLASTICOS',substr(v_cod_error||' - '||v_det_error,1,4000),p_cod_persona);
end prg_val_emi_duo_car_plasticos;
/

