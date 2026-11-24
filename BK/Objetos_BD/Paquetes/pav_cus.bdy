CREATE OR REPLACE PACKAGE BODY IT.PAV_CUS IS
procedure pr_gen_ubi_documento(p_cod_oficina in number,
                              p_fec_vencimiento in date,
                              p_pri_apellido in varchar2,
                              p_ubicacion out varchar2,
                              p_cod_area out number,
                              p_cod_sector out number,
                              p_cod_nivel out number,
                              p_cod_hilera out number,
                              p_cod_seccion out number,
                              p_cod_orden out number)
  is
 v_cod_area      ba_areas.cod_area%type;
 v_cod_sector    cv_sectores.cod_sector%type;
 v_anho          cv_sectores.abreviatura%type;
 v_cod_nivel     cv_niveles.cod_nivel%type;
 v_mes           cv_niveles.abreviatura%type;
 v_cod_hilera    cv_hileras.cod_hilera%type;
 v_semana        cv_hileras.abreviatura%type;
 v_sem           cv_hileras.abreviatura%type;
 v_cod_seccion   cv_secciones.cod_seccion%type;
 v_dia           cv_secciones.abreviatura%type;
 v_orden         cv_orden.abreviatura%type;
 v_sigla         ba_areas.sigla%type;
 v_cod_orden     cv_orden.cod_orden%type;
 v_cod_oficina   ba_oficinas.cod_oficina%type;
 begin
   v_cod_area := fug_obt_pardinamico('CUS_AREA',null,null,null,p_cod_oficina);
   v_cod_oficina := p_cod_oficina;
   --Busca la sigla del área
   begin
     select a.sigla
       into v_sigla
       from ba_areas a
      where a.cod_oficina = v_cod_oficina
        and a.cod_area = v_cod_area;
   exception
      when no_data_found then
         v_cod_oficina := fug_obt_pardinamico('CUS_OFICINA');
         begin
           select a.sigla
             into v_sigla
             from ba_areas a
            where a.cod_oficina = v_cod_oficina
              and a.cod_area = v_cod_area;
         exception
            when no_data_found then
               raise_application_error(-20000,'Area de Custodia no registrada.');
            when others then
               raise_application_error(-20002,'Error al buscar el Area de Custodia.'||sqlerrm);
         end;
      when others then
         raise_application_error(-20001,'Error al buscar el Area de Custodia.'||sqlerrm);
   end;
   select to_char(p_fec_vencimiento,'W')
     into v_sem
     FROM DUAL;
   --Busca el año
   begin
     select s.cod_sector,s.abreviatura
       into v_cod_sector,v_anho
       from cv_sectores s
      where s.cod_oficina = v_cod_oficina
        and s.cod_area = v_cod_area
        and instr(','||s.val_incluidos||',',','||to_char(p_fec_vencimiento,'YYYY')||',') >  0
        and s.estado = 'A';
   exception
     when too_many_rows then
       select s.cod_sector,s.abreviatura
         into v_cod_sector,v_anho
         from cv_sectores s
        where s.cod_oficina = v_cod_oficina
          and s.cod_area = v_cod_area
          and instr(','||s.val_incluidos||',',','||to_char(p_fec_vencimiento,'YYYY')||',') >  0
          and s.estado = 'A'
          and rownum = 1;
     when no_data_found then
        raise_application_error(-20000,'Sector no registrado para el año de la fecha de vencimiento del documento.');
     when others then
        raise_application_error(-20001,'Error al buscar datos del sector.'||sqlerrm);
   end;
   --Busca el mes
   begin
     select n.cod_nivel,n.abreviatura
       into v_cod_nivel,v_mes
       from cv_niveles n
      where n.cod_sector = v_cod_sector
        and n.estado = 'A'
        and instr(','||n.val_incluidos||',',','||to_number(to_char(p_fec_vencimiento,'MM'))||',') >  0;
   exception
     when no_data_found then
        --Si no encuentra por sector, busca sin sector
        begin
          select n.cod_nivel,n.abreviatura
            into v_cod_nivel,v_mes
            from cv_niveles n
           where n.cod_sector is null
             and n.estado = 'A'
             and instr(','||n.val_incluidos||',',','||to_number(to_char(p_fec_vencimiento,'MM'))||',') >  0;
        exception
          when no_data_found then
            raise_application_error(-20002,'Nivel no registrado para el mes de la fecha de vencimiento del documento.');
          when others then
            raise_application_error(-20003,'Error al buscar datos del nivel.'||sqlerrm);
        end;
    when others then
       raise_application_error(20004,'Error al buscar datos del nivel.'||sqlerrm);
    end;
    --Busca la semana
    begin
      select h.cod_hilera,h.abreviatura
        into v_cod_hilera,v_semana
        from cv_hileras h
       where h.cod_nivel = v_cod_nivel
         and h.estado = 'A'
         and instr(','||h.val_incluidos||',',','||v_sem||',') >  0;
    exception
      when no_data_found then
        begin
          select h.cod_hilera,h.abreviatura
            into v_cod_hilera,v_semana
            from cv_hileras h
           where h.cod_nivel is null
             and h.estado = 'A'
             and instr(','||h.val_incluidos||',',','||v_sem||',') >  0;
        exception
          when no_data_found then
             raise_application_error(-20005,'Hilera no registrada para la semana de la fecha de vencimiento del documento.');
          when others then
             raise_application_error(-20006,'Error al buscar datos de la hilera.'||sqlerrm);
        end;
      when others then
        raise_application_error(-20007,'Error al buscar datos de la hilera.'||sqlerrm);
    end;

    --Busca la sección
    begin
      select c.cod_seccion,c.abreviatura
        into v_cod_seccion,v_dia
        from cv_secciones c
       where c.cod_hilera = v_cod_hilera
         and c.estado = 'A'
         and instr(','||c.val_incluidos||',',','||to_number(to_char(p_fec_vencimiento,'DD'))||',') >  0;
    exception
      when no_data_found then
        begin
          select c.cod_seccion,c.abreviatura
            into v_cod_seccion,v_dia
            from cv_secciones c
           where c.cod_hilera is null
             and c.estado = 'A'
             and instr(','||c.val_incluidos||',',','||to_number(to_char(p_fec_vencimiento,'DD'))||',') >  0;
        exception
          when no_data_found then
             raise_application_error(-20008,'Sección no registrada para el día de la fecha de vencimiento.');
          when others then
             raise_application_error(-20009,'Error al buscar datos de la sección.'||sqlerrm);
        end;
      when others then
         raise_application_error(-20010,'Error al buscar datos de la sección.'||sqlerrm);
    end;
    --Busca el orden por apellido
    begin
      select o.abreviatura,o.cod_orden
        into v_orden,v_cod_orden
        from cv_orden o
       where o.cod_seccion = v_cod_seccion
         and o.estado = 'A'
         and instr(','||o.val_incluidos||',',','||substr(p_pri_apellido,1,1)||',') > 0;
    exception
      when no_data_found then
        begin
          select o.abreviatura,o.cod_orden
            into v_orden,v_cod_orden
            from cv_orden o
           where o.cod_seccion is null
             and o.estado = 'A'
             and instr(','||o.val_incluidos||',',','||substr(p_pri_apellido,1,1)||',') > 0;
          exception
            when no_data_found then
              raise_application_error(-20011,'Orden no registrado para la primera letra del apellido.');
            when others then
              raise_application_error(-20012,'Error al buscar datos del orden.'||sqlerrm);
          end;
      when others then
        raise_application_error(-20013,'Error al buscar datos del orden.'||sqlerrm);
    end;
    p_ubicacion := v_sigla||'.'||v_anho||'.'||v_mes||'.'||v_semana||'.'||v_dia||'.'||v_orden;
    p_cod_area := v_cod_area;
    p_cod_sector := v_cod_sector;
    p_cod_nivel := v_cod_nivel;
    p_cod_hilera := v_cod_hilera;
    p_cod_seccion := v_cod_seccion;
    p_cod_orden := v_cod_orden;
 end;

 function fu_en_custodia(p_nro_cuenta in varchar2,
                         p_nro_cuota in number default null)
   return varchar2 is
   v_en_custodia  varchar2(1);
 begin
   begin
     select decode(b.val_maximo,'E','S','S','N')
       into v_en_custodia
       from cv_val_custodias c,
            ba_cod_referencias b
      where c.nro_operacion = p_nro_cuenta
        and c.nro_cuota = p_nro_cuota
        and c.estado = b.val_minimo
        and b.dominio = 'EST_VALORES';
   exception
     when no_data_found then
       v_en_custodia := 'N';
     when others then
       raise_application_error(-20000,'Error al buscar datos de valores en custodia.'||sqlerrm);
   end;

   return v_en_custodia;
 end;
  procedure pr_ins_pag_custodia(p_cod_moneda in varchar2,
                               p_monto in number,
                               p_nro_operacion in varchar2,
                               p_fec_vencimiento in date,
                               p_cod_oficina in number,
                               p_cod_persona in varchar2,
                               p_nom_persona in varchar2,
                               p_nro_secuencia in number,
                               p_hora in varchar2)
    is
    v_cod_val_custodia  cv_val_custodias.cod_val_custodia%type;
    v_tip_valor         cv_val_custodias.tip_valor%type;
    v_fec_actual        ge_calendarios.fec_actual%type := pae_cnf.fu_obt_fec_actual(31);
    v_ubicacion         cv_val_custodias.ubicacion%Type;
    v_cod_area          cv_val_custodias.cod_area%type;
    v_cod_sector        cv_val_custodias.cod_sector%type;
    v_cod_nivel         cv_val_custodias.cod_nivel%type;
    v_cod_hilera        cv_val_custodias.cod_hilera%type;
    v_cod_seccion       cv_val_custodias.cod_seccion%type;
    v_cod_orden         cv_val_custodias.cod_orden%type;
    v_pri_apellido      varchar(300);
  begin
    begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 31; end;

    begin
     select r.val_minimo
       into v_tip_valor
       from ba_cod_referencias r
      where r.dominio = 'TIP_DOC_VAL_CUSTODIA'
        and r.abreviatura is null
        and r.val_maximo = 'I';
   exception
     when no_data_found then
       raise_application_error(-20001,'Tipo de Valor en Custodia no registrado para Pagarés de Préstamos.');
     when others then
       raise_application_error(-20002,'Error al buscar el Tipo de Valor en Custodia.');
   end;

  v_pri_apellido  := pav_cus.fu_obt_pri_apellido(p_cod_persona);

  begin
     pav_cus.pr_gen_ubi_documento(p_cod_oficina,p_fec_vencimiento,v_pri_apellido,v_ubicacion,v_cod_area,
                                   v_cod_sector,v_cod_nivel,v_cod_hilera,v_cod_seccion,v_cod_orden);
  exception
    when others then
       null;
  end;

  update cv_val_custodias c
     set c.est_etiqueta = 'I',
         c.fec_est_etiqueta = v_fec_actual,
         c.ubicacion = v_ubicacion,
         c.cod_area = v_cod_area,
         c.cod_sector = v_cod_sector,
         c.cod_nivel = v_cod_nivel,
         c.cod_hilera = v_cod_hilera,
         c.cod_seccion = v_cod_seccion,
         c.cod_orden = v_cod_orden
   where c.cod_moneda = p_cod_moneda
     and c.cod_persona = p_cod_persona
     and c.nro_operacion = p_nro_operacion
     and c.tip_valor = 'PA';

  if sql%notfound then
    select s_cod_val_custodia.nextval
      into v_cod_val_custodia
      from dual;


     insert into cv_val_custodias(cod_val_custodia,tip_valor,cod_moneda,estado,fec_vencimiento,
                                  monto,nro_operacion,cod_ofi_origen,cod_usu_origen,est_etiqueta,fec_est_etiqueta,
                                  cod_persona,Nom_Persona,ubicacion,cod_area,cod_sector,cod_nivel,cod_hilera,cod_seccion,
                                  cod_orden)
                          values(v_cod_val_custodia,v_tip_valor,p_cod_moneda,'I',p_fec_vencimiento,
                                 p_monto,p_nro_operacion,p_cod_oficina,user,'I',v_fec_actual,p_cod_persona,p_nom_persona,
                                 v_ubicacion,v_cod_area,v_cod_sector,v_cod_nivel,v_cod_hilera,v_cod_seccion,v_cod_orden);

     insert into cv_val_cus_movimientos(fecha,
                                       hora,
                                       cod_usuario,
                                       nro_secuencia,
                                       monto,
                                       cod_val_custodia,
                                       cod_moneda,
                                       est_custodia,
                                       tipo,
                                       estado,
                                       ubicacion,
                                       reversado)
                                values(v_fec_actual,
                                       p_hora,
                                       user,
                                       p_nro_secuencia,
                                       p_monto,
                                       v_cod_val_custodia,
                                       p_cod_moneda,
                                       'I',
                                       1,
                                       'N',
                                       V_ubicacion,
                                       'N');
  end if;
exception
    when others then
    raise_application_error(-20003,'Error al insertar/actualizar en la tabla CV_VAL_CUS_MOVIMIENTOS.'||sqlerrm);

end;
  function fu_obt_pri_apellido (p_cod_persona in varchar2)
    return varchar2 is
    v_pri_apellido  ba_per_fisicas.pri_apellido%type;
    v_raz_social    ba_per_juridicas.raz_social%type;
  begin
      begin
        select ltrim(f.pri_apellido)
          into v_pri_apellido
          from ba_per_fisicas f
         where f.cod_persona = p_cod_persona;
         return v_pri_apellido;
      exception
        when no_data_found then
           begin
             select ltrim(j.raz_social)
               into v_raz_social
               from ba_per_juridicas j
              where j.cod_persona = p_cod_persona;
              return v_raz_social;
           exception
             when no_data_found then
               raise_application_error(-20000,'Persona no registrada.');
             when others then
               raise_application_error(-20001,'Error al buscar Datos de la Persona Jurídica.'||sqlerrm);
           end;
        when others then
          raise_application_error(-20002,'Error al buscar Datos de la Persona Física.'||sqlerrm);
      end;
  end;
end PAV_CUS;
/

