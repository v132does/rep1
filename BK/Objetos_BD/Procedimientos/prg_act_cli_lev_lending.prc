create or replace procedure it.PRG_ACT_CLI_LEV_LENDING is
v_nro_documento   ba_personas.nro_documento%type;
v_tipo varchar2(100);
v_des_tipo varchar2(100);
v_cantidad number(10):=0;
v_ratio varchar2(20);
--
  cursor c_datos is
    select * from GE_CLI_LEV_LENDING_TMP;

begin
  Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo :=1; end;


  for val in c_datos loop
    v_tipo:=null;
    v_des_tipo:=null;
    v_nro_documento:=null;
    --- Validamos si existe el Nro de Documento
    Begin
      select a.nro_documento
        into v_nro_documento
        from ba_personas a
       where a.cod_persona = val.cod_persona
       and rownum=1;
    exception
      when no_data_found then
        raise_application_error(-20000,'Cliente : ' || val.cod_persona ||' no existe en el sistema, verifique planilla');
      when others then
        raise_application_error(-20000,'Al Obt. Persona : ' || sqlerrm);
    end;

    --- Validamos si existe el tipo y la descripcion en ba_cod_referencias
    Begin
      select trim(upper(a.val_minimo)), trim(upper(a.significado))
       into v_tipo, v_des_tipo
        from ba_cod_referencias a
          where upper(a.dominio) like 'TIP_LEVERAGED'
            and trim(upper(a.val_minimo))= trim(upper(val.tipo))
            and trim(upper(a.significado))= trim(upper(val.descripcion));
     exception
      when no_data_found then
        raise_application_error(-20000,'Tipo y Descripcion' || upper(val.tipo) ||' -  '|| upper(val.descripcion) ||' no parametrizado en el sistema, verifique planilla');
      when others then
        raise_application_error(-20000,'Al Obt. Tipo y Descripcion: ' || sqlerrm);
    end;

    --Verificamos si ya existe en la tabla
    v_cantidad:=0;
    Begin
      select nvl(count(*),0)
       into v_cantidad
        from ge_cli_lev_lending a
          where a.cod_persona= val.cod_persona
           and a.nro_documento= v_nro_documento
           and a.mes= val.mes
           and a.anho=val.anho;
     exception
      when no_data_found then
         v_cantidad:=0;
      when others then
          v_cantidad:=1;
    end;

    v_ratio :='0';
    /*select to_number(REPLACE(val.ratio,',','.'), '999D00', 'nls_numeric_characters=''. ''')
    into v_ratio
     from dual;*/
     
    v_ratio:=  val.ratio;



   if NVL(v_cantidad,0)= 0 then
     --- Insertamos en la tabla ge_cli_lev_lending
      Begin
       insert into  ge_cli_lev_lending(COD_PERSONA,NRO_DOCUMENTO,TIPO,DESCRIPCION,ANHO,MES,RATIO)
       values(val.cod_persona, trim(upper(v_nro_documento)), trim(upper(val.tipo)), trim(upper(val.descripcion)),
       val.anho, val.mes, v_ratio/*val.ratio*/);

      exception
        when others then
          raise_application_error(-20000,'Al insertar -Cod.Cliente: ' || val.cod_persona ||'-Tipo: '||val.tipo||'-Mes:'||val.mes||sqlerrm);
      end;
   else
     --Actualizamos los datos
      Begin
          update ge_cli_lev_lending a
             set a.ratio= v_ratio,
                 a.tipo= val.tipo,
                 a.descripcion= val.descripcion
            where a.cod_persona= val.cod_persona
             and a.nro_documento= v_nro_documento
             and a.mes= val.mes
             and a.anho=val.anho;
      exception
        when others then
          raise_application_error(-20000,'No se puede actualizar: ' || val.cod_persona ||'-Tipo: '||val.tipo||'-Mes:'||val.mes||sqlerrm);
      end;

   end if;
end loop;
    commit;

end PRG_ACT_CLI_LEV_LENDING;
/

