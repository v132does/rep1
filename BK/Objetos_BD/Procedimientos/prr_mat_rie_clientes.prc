create or replace procedure it.PRR_MAT_RIE_CLIENTES (p_cod_persona varchar2 default null
                                             --,p_ind_historico varchar2 default 'N'
                                             )
                                            IS
cursor pun_ele (p_persona varchar2) is
  select (sum(pun.puntaje) / count(*)) pro_ele,
         pun.cod_persona, pun.cod_puntaje,
         con.cod_gru_concepto
  from cr_pun_personas pun, cr_pun_conceptos con
  where pun.cod_puntaje = fug_obt_pardinamico('COD_PUN_MAT_RIE')
  and con.cod_puntaje = pun.cod_puntaje
  and con.cod_campo = pun.cod_campo
  and (pun.cod_persona = p_persona OR p_persona is null)
  and pun.puntaje > 0
  group by pun.cod_persona, pun.cod_puntaje,
  con.cod_gru_concepto
  order by 3,4;
cursor pun_per (p_persona varchar2) is
  select sum(rie_elemento)/count(cod_persona) pro_persona,
         cod_persona , cod_puntaje
  from cr_per_pun_elementos
  where cod_puntaje = fug_obt_pardinamico('COD_PUN_MAT_RIE')
  and (cod_persona = p_persona or p_persona is null)
  group by cod_persona, cod_puntaje
  order by cod_persona;
--v_persona ba_personas.cod_persona%TYPE := p_cod_persona;
v_puntaje number(10);

begin
  --limpia la tabla
  begin
       delete
       from cr_per_pun_elementos
       where (cod_persona = p_cod_persona or p_cod_persona is null);
  end;
   begin
     for x in pun_ele(p_cod_persona) loop
         begin
          select max(puntaje)
             into v_puntaje
             from  cr_pun_rie_sugeridos
             where pun_desde<= x.pro_ele
             and   pun_hasta > = x.pro_ele
             and   cod_puntaje = x.cod_puntaje;
          exception
          when others then
          v_puntaje := 1;
         end;
     insert into cr_per_pun_elementos
     (COD_PERSONA,    COD_PUNTAJE,
     COD_ELEMENTO,   PUN_ELEMENTO, RIE_ELEMENTO, usu_insercion)
     values
     (x.cod_persona,       x.cod_puntaje,
     x.cod_gru_concepto,  x.pro_ele,v_puntaje, user);
     end loop;
    commit;
   end;
 begin
   for y in pun_per(p_cod_persona) loop
    begin
          select max(puntaje)
             into v_puntaje
             from  cr_pun_rie_sugeridos
             where pun_desde<= y.pro_persona
             and   pun_hasta > = y.pro_persona
             and   cod_puntaje = y.cod_puntaje;
          exception
          when others then
          v_puntaje := 1;
     end;
   begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; end;
   update cr_per_puntajes
    set pro_riesgo = y.pro_persona,
    rie_sugerido = v_puntaje
    where cod_persona = y.cod_persona
    and   cod_puntaje = y.cod_puntaje;
   end loop;
 end;
end;
/

