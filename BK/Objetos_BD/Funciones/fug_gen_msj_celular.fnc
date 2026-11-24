create or replace function it.fug_gen_msj_celular (p_mensaje in varchar2)
return varchar2 is
v_cod_persona varchar2(20);
v_mensaje varchar2(4000);
v_texto varchar2(500);
v_celular varchar2(50);
v_fecha   varchar2(30);
v_pos_ini number;
v_pos_fin number;
v_parte   varchar2(1000);
---
procedure lp_gen_msj_celular(p_celular in varchar2, p_fecha in varchar2, p_texto in varchar2) is
v_texto varchar2(200);
begin
   -- busco la persona dueña del celular
   begin
   select cod_persona
     into v_cod_persona
     from ba_telefonos x
    where substr(area||telefono,-9) = substr(p_celular,-9)
      and x.tip_linea = 'C'
      and rownum = 1;
   exception
     when others then
         v_cod_persona := null;
   end;
   v_texto := upper(trim(p_texto));
   if v_texto like 'CANTA%' then
      v_texto := trim(replace(v_texto,'CANTA',''));
      if v_texto like 'AG%' then
         v_texto := 'AGUSTIN MEZA';
      elsif v_texto like 'RAM%' then
         v_texto := 'RAMON BATTAGLIA';
      elsif v_texto like 'GU%' then
         v_texto := 'GUSTAVO BENITEZ';
      elsif v_texto like 'ER%' then
         v_texto := 'ERNESTO  VAZQUEZ';
      elsif v_texto like 'VA%' then
         v_texto := 'VALERIA CAPRA';
      elsif v_texto like 'RO%' then
         v_texto := 'RODOLFO GONZALEZ';
       elsif v_texto like 'IN%' then
         v_texto := 'INGRID LARRAIN';
      elsif v_texto like 'RAQ%' then
         v_texto := 'RAQUEL AMARILLA';
      elsif v_texto like 'PA%' then
         v_texto := 'PAOLA VAZQUEZ';
      elsif v_texto like 'JU%' then
         v_texto := 'JULIO LEGUIZAMON';
      elsif v_texto like 'ALB%' then
         v_texto := 'ALBA VERA';
      elsif v_texto like 'ZU%' then
         v_texto := 'ZUNY BAREIRO';
      elsif v_texto like 'JO%' then
         v_texto := 'JOSE DIAZ';
      elsif v_texto like 'AD%' then
         v_texto := 'ADRIAN SAUCEDO';
      elsif v_texto like 'CA%' then
         v_texto := 'CAROLINA SANCHEZ';
      elsif v_texto like 'CO%' then
         v_texto := 'GUSTAVO CORTESE';
      elsif v_texto like 'AL%' then
         v_texto := 'ALEJANDRA ALVARADO';
      end if;
      insert into cr_per_notas
                      (cod_persona, tipo, fecha, descripcion, detalle, estado, medio, automatico)
       values (v_cod_persona, 'C', trunc(sysdate), 'Su Voto ya ha sido registrado.Muchas Gracias', 'Respuesta al mensaje del Celular '||p_celular||' recibido el '||p_fecha, 'P','C','S');

   elsif substr(v_texto,1,1) between '0' and '9' and length(v_texto) < 10 and v_cod_persona is not null then
      -- busco el saldo de la cuenta
      begin
      select 'El saldo de su Cta.'||v_texto||' es '||cod_moneda||' '||trim(to_char(sal_contable,'999,999,999,999.99'))
        into v_texto
        from ge_cuentas a
       where nro_cuenta = v_texto
         and exists (select 0 from ge_cta_clientes b
                      where a.nro_cuenta = b.nro_cuenta
                        and b.cod_persona = v_cod_persona);
      exception
        when no_data_found then
          v_texto := 'El Nro. de Cuenta '||v_texto||' no le corresponde a Ud. Verifique.';
      end;
      insert into cr_per_notas
                      (cod_persona, tipo, fecha, descripcion, detalle, estado, medio, automatico)
       values (v_cod_persona, 'C', trunc(sysdate), v_texto, 'Respuesta al mensaje del Celular '||p_celular||' recibido el '||p_fecha, 'P','T','S');
   end if;
   insert into ge_log_sms(
      cod_persona, fecha, telefono, tipo, mensaje)
   values
      (v_cod_persona, pag_cal.FU_OBT_FEC_ACTUAL(1),
       p_celular, 'R', v_texto);
end;
---
begin
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
   v_mensaje := p_mensaje;
   loop
      v_pos_ini := instr(v_mensaje,'<F:') + 3;
      exit when nvl(v_pos_ini,3) = 3;
      v_pos_fin := instr(v_mensaje,'>>') - 4;
      v_parte := substr(v_mensaje,v_pos_ini, v_pos_fin);
      v_mensaje := substr(v_mensaje,v_pos_fin + 6);
      -- tomo la fecha
      v_pos_ini := 1;
      v_pos_fin := instr(v_parte,'C:');
      v_fecha := substr(v_parte,v_pos_ini,v_pos_fin-2);
      v_pos_ini := v_pos_fin+2;
      v_pos_fin := instr(v_parte,'T:');
      v_celular := substr(v_parte,v_pos_ini,v_pos_fin - 1 - v_pos_ini);
      v_texto := substr(v_parte, v_pos_fin + 2);
      lp_gen_msj_celular(v_celular, v_fecha, v_texto);
   end loop;
   return null;

exception
  when no_data_found then
    return null;
  when others then
    raise_application_error(-20000,'Error al leer mensaje para el celular '||sqlerrm);
end;
/

