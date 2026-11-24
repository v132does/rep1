create or replace procedure it.prg_ins_sus_masivas is
  v_cod_persona ba_personas.cod_persona%type;
  v_yasuscripto varchar2(1) := 'N';
  v_clidestino varchar2(1) := 'N';
  v_nro_telefono varchar2(20);
  v_error varchar2(4000);
  v_des_activo bw_not_cli_destino.activo%type;
  v_sus_activo Bw_Not_Suscripciones.Activo%type;
  v_suscribir varchar2(1) := 'S';

  cursor c_suscripciones is
  select a.cod_persona, a.nro_cuenta
    from ge_cta_clientes a, bw_not_sus_masivas_tmp b
   where a.cod_persona =
         nvl(b.cod_persona, fue_obt_cod_persona(b.nro_documento))
     and a.relacion = 'P'
     and a.cod_modulo in
         (select b.val_maximo
            from ba_cod_referencias b
           where b.dominio = 'EVE_SUS_MASIVAS');

  cursor c_eventos is
  select a.val_minimo cod_evento, a.val_maximo cod_modulo
    from ba_cod_referencias a
   where a.dominio = 'EVE_SUS_MASIVAS';

  procedure pr_ins_log_errores(p_cod_persona varchar2, p_lugar varchar2, p_det_error varchar2) is
    pragma autonomous_transaction;
  begin
    insert into ge_log_errores(cod_programa, campo1, dato1, campo2, dato2, det_error)
    values ('PRG_INS_SUS_MASIVAS','Persona:',p_cod_persona,'Lugar:',p_lugar, p_det_error);
    commit;
  exception
    when others then null;
  end;
begin
  Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
  for sus in c_suscripciones loop
    v_suscribir := 'S';
    -- Se verifica que exista la persona
    begin
      select a.cod_persona into v_cod_persona
        from ba_personas a
       where a.cod_persona = sus.cod_persona;
    exception
      when no_data_found then v_cod_persona := null;
      when others then v_cod_persona := null;
    end;
    -- Se verifica que tenga un destino activo. bw_not_cli_destino
    begin
      select 'S', a.activo
        into v_clidestino, v_des_activo
        from bw_not_cli_destino a
       where a.cod_persona = sus.cod_persona
         and a.cod_destino = 1
         and rownum <=1;
    exception
      when no_data_found then
        v_clidestino := 'N';
      when others then
        v_clidestino := 'N';
    end;
    -- Si no existe, se inserta el destino
    if nvl(v_clidestino,'N') = 'N' then
      -- Se busca si tiene un número de celular.
      begin
         select a.area||a.telefono
           into v_nro_telefono
           from ba_telefonos a
          where a.cod_persona= sus.cod_persona
            and a.tip_linea='C'
            and a.observacion is null
            and rownum = 1;
      exception
        when no_data_found then
           v_nro_telefono:=  null;
        when others then
           v_nro_telefono:=  null;
      end;
      if v_nro_telefono is not null then
        begin
          insert into bw_not_cli_destino(cod_persona,cod_destino,direccion,activo,cod_origen)
          values(sus.cod_persona, 1, v_nro_telefono, 'S', 'SMS');
        exception
          when others then
            v_error := sqlerrm;
            v_suscribir := 'N';
            pr_ins_log_errores(sus.cod_persona, 'Insertar bw_not_cli_destino', v_error);
        end;
      else
        v_suscribir := 'N';
        pr_ins_log_errores(sus.cod_persona, 'No tienen Nro. Celular', null);
      end if;
    else
      -- Tiene destino, se verifica si está activo o no.
      if nvl(v_des_activo,'N') = 'N' then
        -- Se procede a activar
        begin
          select 'S' into v_des_activo
            from bw_not_cli_destino a
           where a.cod_persona = sus.cod_persona
             and a.cod_destino = 1
             and a.activo = 'S'
             and rownum = 1;
        exception
          when no_data_found then null;
          when others then null;
        end;
        if nvl(v_des_activo,'N') = 'N' then
          begin
            update bw_not_cli_destino a
               set a.activo = 'S'
             where a.cod_persona = sus.cod_persona
               and a.cod_destino = 1
               and a.activo = 'N'
               and a.fec_insercion =
                   (select max(b.fec_insercion)
                      from bw_not_cli_destino b
                     where b.cod_persona = a.cod_persona
                       and b.cod_destino = a.cod_destino
                       and b.activo = a.activo)
               and rownum = 1;
          exception
            when others then
              v_error := sqlerrm;
              pr_ins_log_errores(sus.cod_persona, 'Activar en bw_not_cli_destino', v_error);
          end;
        end if;
      end if;
    end if;
    -- Por cada Evento a Suscribirse se verifica la suscripción.
    for eve in c_eventos loop
      if v_cod_persona is not null then
        -- Se verifica si ya está suscripto a algunos de los eventos.
        begin
          select 'S', a.activo
            into v_yasuscripto, v_sus_activo
            from bw_not_suscripciones a
           where a.cod_persona = sus.cod_persona
             and a.nro_cuenta = sus.nro_cuenta
             and a.cod_evento = eve.cod_evento;
        exception
          when no_data_found then
            v_yasuscripto := 'N';
          when others then
            v_yasuscripto := 'N';
        end;
        if nvl(v_yasuscripto,'N') = 'N' and v_suscribir = 'S' then
          begin
            insert into bw_not_suscripciones(cod_persona, nro_cuenta, cod_evento, activo)
            values(sus.cod_persona, sus.nro_cuenta, eve.cod_evento, 'S');
          exception
            when others then
              v_error := sqlerrM;
              pr_ins_log_errores(sus.cod_persona, 'Insertar bw_not_suscripciones', v_error);
          end;
        else
          if v_sus_activo = 'N' then
            begin
              update bw_not_suscripciones a
                 set a.activo = 'S'
               where a.cod_persona = sus.cod_persona
                 and a.nro_cuenta = sus.nro_cuenta
                 and a.cod_evento = eve.cod_evento;
            exception
              when others then
                v_error := sqlerrm;
                pr_ins_log_errores(sus.cod_persona, 'Activar en bw_not_suscripciones', v_error);
            end;
          end if;
        end if;
      end if;
    end loop;
  end loop;
  commit;
end;
/

