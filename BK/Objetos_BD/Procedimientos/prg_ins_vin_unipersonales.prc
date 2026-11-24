create or replace procedure it.prg_ins_vin_unipersonales(p_error in out varchar2,
                                                      p_mensaje in out varchar2) is

--https://itti-digital.atlassian.net/browse/NVB-3811
   /*
     Cursor que nos devuelve la lista de unipersonales que NO tienen
     un vinculo del tipo UN en ba_vinculos
   */
cursor cur_uni is
select ju.cod_persona cod_persona_juridica,
       substr(ba.nro_documento, 1, instr(ba.nro_documento, '-') - 1) ruc_sin_dv,
       ba.nro_documento ruc
  from ba_per_juridicas ju,
       ba_personas ba
 where ju.naturaleza = '21'
   and ba.nro_documento not like '800%'
   and ju.cod_persona = ba.cod_persona
   and not exists (select 1
          from ba_vinculos ba
         where ba.cod_persona = JU.cod_persona
           and ba.tipo = 'UN');
/*
  cursor que utilizamos para devolver el registro donde coinciden
  ruc_sin_dv = nro_documento - en teoria solo debe de devolver un registro
  podría darse el caso de que devuelva más registros por eso antes de insertar
  validamos si ya tenemos un vinculo del tipo UN
*/
cursor cur_fisica(p_nro_documento ba_personas.nro_documento%type) is
  select ba.cod_persona cod_persona_fisica,
         ba.nro_documento ci
  from ba_per_fisicas fi,
       ba_personas ba
  where fi.cod_persona = ba.cod_persona
  and ba.nro_documento = p_nro_documento
  and ba.cod_tip_documento = 1; --CI

  v_error exception;
  
  function fu_tiene_vinculo(v_cod_persona ba_vinculos.cod_persona%type) return varchar2 is
    v_existe varchar2(1);
  begin
    select 'S'
    into v_existe
    from ba_vinculos a
    where a.cod_persona = v_cod_persona
    and a.tipo = 'UN';
    
    return v_existe;
    exception
      when too_many_rows then
        return 'S';
      when no_data_found then
        return 'N';
      when others then
        return 'N';
  end;

begin
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;
  FOR dato in cur_uni loop
      for pers in cur_fisica(dato.ruc_sin_dv) loop
        begin
          --Verificamos otra ves si tiene vinculo
          if nvl(fu_tiene_vinculo(dato.cod_persona_juridica), 'N') = 'N' then
            --Insertmaos el vinculo
            insert into ba_vinculos
           (cod_persona,
            cod_per_vinculo,
            tipo,
            activo,
            estado)
            values(
            dato.cod_persona_juridica,
            pers.cod_persona_fisica,
            'UN',
            'S',
            'A');
          end if;
        exception
          when others then
            --En el caso de que haya un error pateas y hacemos rollback 
             p_error := '01';
             p_mensaje := 'Error per. Jur.: '|| dato.cod_persona_juridica || ' - ' || sqlerrm;
             raise v_error;

        end;
      end loop;
  end loop;


   p_error := '00';
   p_mensaje := null;
   commit;
  exception
    when v_error then
      rollback;
      null;
    when others then
      rollback;
      p_error := '99';
      p_mensaje := 'Error ' || ' - ' || sqlerrm;
end;
/

