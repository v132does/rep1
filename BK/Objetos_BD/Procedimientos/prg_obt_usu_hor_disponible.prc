create or replace procedure it.prg_obt_usu_hor_disponible (p_fecha       in date,
                                                           p_hora        in out varchar2,
                                                           p_cod_usuario in out varchar2,
                                                           p_es_nocturno in varchar2) is
  /* obtiene usuario y hora que no esté utilizado en movimientos
  retorna usuario + 1 en caso de que el usuario actual no disponga de
  horarios disponibles para los movimientos*/
  v_existe_usu varchar2(1);
  v_existe varchar2(1);
  v_hora_max   ge_movimientos.hora%type;
  v_base   varchar2(10);
  v_indice number(10);
  v_can_reg_usuario       number(10);
begin

  if p_es_nocturno = 'N' then
    begin
      select  regexp_replace(p_cod_usuario , '[^a-zA-Z]', ''),decode(max(nvl(regexp_replace(a, '[^0-9]', ''),0)),0,'',max(nvl(regexp_replace(a, '[^0-9]', ''),0)))
      into v_base,v_indice
      from (
      select  distinct cod_usuario a from ge_movimientos a
      where cod_usuario like regexp_replace(p_cod_usuario , '[^a-zA-Z]', '')||'%');
      end;
    if nvl(v_indice,0)=0 then
      p_cod_usuario:=v_base;
    else
      p_cod_usuario:=v_base||'_'||v_indice;
    end if;
    
    begin
         select count(*),nvl(max(hora),'00:00:00')
         into v_can_reg_usuario,v_hora_max
         from(
         select hora
          from ge_movimientos
          where fecha = p_fecha
          and cod_usuario = p_cod_usuario
          group by hora);
      exception
        when no_data_found then
             v_can_reg_usuario:=0;             
      end;
      if v_can_reg_usuario<>0 then
       p_hora:=pag_gen.fu_obt_sig_segundo(v_hora_max);
      end if;
      
       if v_can_reg_usuario=0 or v_can_reg_usuario<86400 then
         
             loop
                begin
                  select 'S'
                    into v_existe
                    from ge_movimientos
                   where fecha = p_fecha
                     and hora = p_hora
                     and cod_usuario = p_cod_usuario
                     and rownum <= 1;
                exception
                  when no_data_found then
                    v_existe := 'N';
                end;
                exit when v_existe = 'N';
                p_hora:= pag_gen.fu_obt_sig_segundo(p_hora);
              end loop;
       elsif v_can_reg_usuario=86400 then
         p_cod_usuario:=v_base||'_'||(nvl(v_indice,0)+1);
          begin
            select distinct 'S'
            into v_existe_usu
            from ba_usuarios s
            where s.cod_usuario=p_cod_usuario;
            exception
              when no_data_found then
                v_existe_usu:='N';
           end;
           if v_existe_usu='S' then
                p_hora := '00:00:00';
                loop
                  begin
                    select 'S'
                      into v_existe
                      from ge_movimientos
                     where fecha = p_fecha
                       and hora = p_hora
                       and cod_usuario = p_cod_usuario
                       and rownum <= 1;
                  exception
                    when no_data_found then
                      v_existe := 'N';
                  end;
                  exit when v_existe = 'N';
                  p_hora := pag_gen.fu_obt_sig_segundo(p_hora);
                end loop;
             else
             raise_application_error(-20000,'No quedan segundos disponibles,verifique');
             end if; 
       end if;
       
  else
    
  begin
      select  regexp_replace(p_cod_usuario , '[^a-zA-Z]', ''),decode(max(nvl(regexp_replace(a, '[^0-9]', ''),0)),0,'',max(nvl(regexp_replace(a, '[^0-9]', ''),0)))
      into v_base,v_indice
      from (
      select  distinct cod_usuario a from ge_movimientos_noc a
      where cod_usuario like regexp_replace(p_cod_usuario , '[^a-zA-Z]', '')||'%');
      end;
    if nvl(v_indice,0)=0 then
      p_cod_usuario:=v_base;
    else
      p_cod_usuario:=v_base||'_'||v_indice;
    end if;
    
    begin
         select count(*),nvl(max(hora),'00:00:00')
         into v_can_reg_usuario,v_hora_max
         from(
         select hora
          from ge_movimientos_noc
          where fecha = p_fecha
          and cod_usuario = p_cod_usuario
          group by hora);
      exception
        when no_data_found then
             v_can_reg_usuario:=0;
      end;
      if v_can_reg_usuario<>0 then
      p_hora:=pag_gen.fu_obt_sig_segundo(v_hora_max);
      end if;
       if v_can_reg_usuario=0 or v_can_reg_usuario<86400 then
         
             loop
                begin
                  select 'S'
                    into v_existe
                    from ge_movimientos_noc
                   where fecha = p_fecha
                     and hora = p_hora
                     and cod_usuario = p_cod_usuario
                     and rownum <= 1;
                exception
                  when no_data_found then
                    v_existe := 'N';
                end;
                exit when v_existe = 'N';
                p_hora:= pag_gen.fu_obt_sig_segundo(p_hora);
              end loop;
       elsif v_can_reg_usuario=86400 then
         p_cod_usuario:=v_base||'_'||(nvl(v_indice,0)+1);
          begin
            select distinct 'S'
            into v_existe_usu
            from ba_usuarios s
            where s.cod_usuario=p_cod_usuario;
            exception
              when no_data_found then
                v_existe_usu:='N';
           end;
           if v_existe_usu='S' then
                p_hora := '00:00:00';
                loop
                  begin
                    select 'S'
                      into v_existe
                      from ge_movimientos_noc
                     where fecha = p_fecha
                       and hora = p_hora
                       and cod_usuario = p_cod_usuario
                       and rownum <= 1;
                  exception
                    when no_data_found then
                      v_existe := 'N';
                  end;
                  exit when v_existe = 'N';
                  p_hora := pag_gen.fu_obt_sig_segundo(p_hora);
                end loop;
             else
             raise_application_error(-20000,'No quedan segundos disponibles NOC,verifique');
             end if; 
       end if;
         
   end if;
end;
/

