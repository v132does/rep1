create or replace procedure it.insertar_proveedores_unicos is
  cursor c_prov_unicos is
  select a.nro_ruc, a.nro_timbrado, a.nro_cuenta, a.moneda, a.nom_proveedor, a.retiene_iva,
         decode(a.cod_persona, null, fue_obt_cod_persona_doc(6, trim(a.nro_ruc)), a.cod_persona) cod_persona,
         a.tipo_persona, a.cod_ente
    from tmp_prov_v2 a
   where not exists (select b.nro_ruc, count(1)
            from tmp_prov_v2 b
           where b.nro_ruc = a.nro_ruc
           group by b.nro_ruc
          having count(1) > 1)
   order by a.nro_ruc;

  v_cod_ente ge_entes.cod_ente%type;
  v_cod_persona ba_personas.cod_persona%type;
  v_pri_nombre ba_per_fisicas.pri_nombre%type;
  v_pri_apellido ba_per_fisicas.pri_apellido%type;
  v_ruc tmp_prov_v2.nro_ruc%type;
begin
  begin pre_ini_aplicacion; pae_cnf.g_cod_modulo:=1 ; end;
  for x in c_prov_unicos loop
     v_cod_ente := null;
     v_cod_persona := null;
     v_pri_nombre := null;
     v_pri_apellido := null;
     v_ruc := x.nro_ruc;
     select max(e.cod_ente) + 1 into v_cod_ente from ge_entes e where e.cod_ente < 2000;

     if x.cod_persona is null then
       select s_cod_persona.nextval into v_cod_persona from dual;

       select substr(substr(x.nom_proveedor, 1, decode(instr(x.nom_proveedor, ' ', 1),0,length(x.nom_proveedor), instr(x.nom_proveedor, ' ', 1)-1)),1,30)
         into v_pri_nombre from dual;

       select substr(substr(x.nom_proveedor, decode(instr(x.nom_proveedor, ' ', 1),1,length(x.nom_proveedor), instr(x.nom_proveedor, ' ', 1)+1), length(x.nom_proveedor)),1,30)
         into v_pri_apellido from dual;

       begin
         insert into ba_personas(cod_persona, tipo, cod_tip_documento, nro_documento, cod_pais)
            values (v_cod_persona, x.tipo_persona, 6, lpad(x.nro_ruc,10,'0'), 1);
       exception
         when others then
            raise_application_error(-20000, 'Error al insertar ba_personas: '||x.nro_ruc||' '||sqlerrm);
       end;
       ---Insertar en ba_per_fisicas o ba_per_juridicas
       if x.tipo_persona = 'F' then
          begin
            insert into ba_per_fisicas(cod_persona, pri_nombre, pri_apellido, est_civil, cod_sexo)
              values(v_cod_persona, v_pri_nombre, v_pri_apellido, 'S', 'M');
          exception
            when others then
              raise_application_error(-20000, 'Error al insertar ba_per_fisicas: '||x.nro_ruc||' '||sqlerrm);
          end;
       else
          begin
            insert into ba_per_juridicas(cod_persona, raz_social, nom_comercial)
              values(v_cod_persona, x.nom_proveedor, x.nom_proveedor);
          exception
            when others then
              raise_application_error(-20000, 'Error al insertar ba_per_juridicas: '||x.nro_ruc||' '||sqlerrm);
          end;
       end if;
     else
       v_cod_persona := x.cod_persona;
     end if;
     ---Insertar en ge_entes
     begin
       insert into ge_entes(cod_ente,descripcion,cod_persona,tipo) values (v_cod_ente, trim(x.nom_proveedor),v_cod_persona,'PV');
     exception
         when others then
            raise_application_error(-20000, 'Error al insertar ge_entes: '||x.nro_ruc||' '||sqlerrm);
     end;

     --Insertar parametros del ente
     if trim(x.nro_timbrado) is not null then
       begin
         insert into ge_par_entes(cod_ente,parametro,val_parametro) values(v_cod_ente, 'ULT_NRO_TIMBRADO', x.nro_timbrado);
       exception
         when others then
            raise_application_error(-20000, 'Error al insertar ge_par_entes: '||x.nro_ruc||' ULT_NRO_TIMBRADO '||sqlerrm);
       end;
     end if;
     if trim(x.nro_cuenta) is not null then
       begin
         insert into ge_par_entes(cod_ente,parametro,val_parametro) values(v_cod_ente, 'NRO_CTA_PPROV', x.nro_cuenta);
       exception
         when others then
            raise_application_error(-20000, 'Error al insertar ge_par_entes: '||x.nro_ruc||' NRO_CTA_PPROV '||sqlerrm);
       end;
     end if;
     if trim(x.retiene_iva) is not null then
       begin
         insert into ge_par_entes(cod_ente,parametro,val_parametro) values(v_cod_ente, 'CON_RETENCION', x.retiene_iva);
       exception
         when others then
            raise_application_error(-20000, 'Error al insertar ge_par_entes: '||x.nro_ruc||' CON_RETENCION '||sqlerrm);
       end;
     end if;

  end loop;
exception
  when others then
    raise_application_error(-20000, 'Error RUC:'||v_ruc||' '||sqlerrm);
end;
/

