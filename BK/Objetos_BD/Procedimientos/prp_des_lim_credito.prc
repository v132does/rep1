CREATE OR REPLACE PROCEDURE IT.PRP_DES_LIM_CREDITO
 (P_NRO_LINEA IN PR_LINEAS.NRO_LINEA%TYPE
 ,P_NRO_CUENTA IN varchar2
 ,P_NRO_SECUENCIA IN CC_LIN_SOBREGIROS.NRO_SECUENCIA%TYPE default null
 )
 IS
  verror          EXCEPTION;
  vmensaje        VARCHAR2(1000);
  v_cod_modulo    ge_cuentas.cod_modulo%type;
  v_cod_modalidad ge_cuentas.cod_modalidad%type;
  v_es_solicitud  varchar2(1);
  
begin
  If p_nro_cuenta is not null then
    begin
      select cod_modulo, cod_modalidad
        into v_cod_modulo, v_cod_modalidad
        from ge_cuentas
        where nro_cuenta = p_nro_cuenta;
      v_es_solicitud := 'N';
    exception
      when no_data_found then
         begin
           select cod_modulo
             into v_cod_modulo
             from pr_solicitudes
            where nro_solicitud = to_number(replace(p_nro_cuenta, 'Prop.Nro. ',''));
           v_es_solicitud := 'S';
         exception
           when verror then
             raise verror;
           when others then
             begin
               select cod_modulo, cod_modalidad
                 into v_cod_modulo, v_cod_modalidad
                 from ta_solicitudes
                where nro_solicitud = to_number(replace(p_nro_cuenta, 'Sol.Nro.',''));
               v_es_solicitud := 'S';
             exception
               when verror then
                 raise verror;
               when others then
                 vmensaje := 'ERROR. No existe la operación '||p_nro_cuenta;
                 raise verror;
             end;           
         end;
      when verror then
        raise verror;
      when others then
        vmensaje := 'ERROR. No existe la operación';
        raise verror;
    end;
    If v_cod_modulo = 4 then
      begin
        update cc_lin_sobregiros ls
           set estado = 'C'/*nro_linea = null,
               tipo      = 'T'*/
         where ((nro_secuencia = p_nro_secuencia
           and nro_linea = p_nro_linea)
            or (nro_sec_padre = p_nro_secuencia
           and nro_linea = p_nro_linea))
           and exists (Select '1'
                             from pr_lineas l, pr_lin_aplicaciones a
                            where a.nro_sec_padre = ls.nro_sec_padre
                              and l.nro_linea != ls.nro_linea
                              and l.cod_persona = ls.cod_persona
                              and l.estado not in ('A', 'P'));
      exception
        when verror then
          raise verror;
        when others then
          vmensaje := 'ERROR. Al actualizar sobregiros ' || sqlerrm;
          raise verror;
      end; 
                               
    elsif v_cod_modulo = 5 then
      begin
        If v_es_solicitud = 'N' then
          update ta_cta_tarjetas
               set nro_linea = null
             where nro_cuenta = p_nro_cuenta
               and nro_linea = p_nro_linea;
        else
          update ta_solicitudes 
             set nro_linea = null
           where nro_solicitud = to_number(replace(p_nro_cuenta, 'Sol.Nro.',''))
             and nro_linea = p_nro_linea;        
        End if;
      exception
        when verror then
          raise verror;
        when others then
          vmensaje := 'ERROR. Al actualizar tarjetas ' || sqlerrm;
          raise verror;
      end;
    elsif v_cod_modulo = 6 then
      begin
        If v_es_solicitud = 'N' then
          update pr_cta_prestamos
               set nro_linea = null
             where nro_cuenta = p_nro_cuenta
               and nro_linea = p_nro_linea;
        End if;
        If v_es_solicitud = 'S' then
           update pr_solicitudes
              set nro_linea = null
            where nro_solicitud = replace(p_nro_cuenta, 'Prop.Nro. ','')
              and nro_linea = p_nro_linea;
        end if;
      exception
        when verror then
          raise verror;
        when others then
          vmensaje := 'ERROR. Al actualizar prestamos ' || sqlerrm;
          raise verror;
      end;
    elsif v_cod_modulo = 8 then -- Comercio Exterior.
      BEGIN
        IF v_cod_modalidad = 81 then  -- CARTA DE CREDITO DE IMPORTACION
           Update CX_cta_importaciones
              set nro_linea = null
            where nro_cuenta = p_nro_cuenta
              and nro_linea = p_nro_linea;
        Elsif v_cod_modalidad = 82  then -- CARTA DE CREDITO DE EXPORTACION
           Update CX_cta_exportaciones
              set nro_linea = null
            where nro_cuenta = p_nro_cuenta
              and nro_linea = p_nro_linea;
        Elsif v_cod_modalidad in (88, 89) then -- FIANZAS LOCALES y FIANZAS EXTERIOR
           Update CX_fianzas
              set nro_linea = null
            where nro_cuenta = p_nro_cuenta
              and nro_linea = p_nro_linea;
        End if;
      EXCEPTION
        when verror then
          raise verror;
        when others then
          vmensaje := 'ERROR. Al actualizar cuenta de comercio exterior ' || sqlerrm;
          raise verror;
      END;
    elsif v_cod_modulo = 10 then -- Mesa de Dinero.  
     BEGIN
          Update md_cta_documentos c
            set c.nro_linea = null
          where c.nro_cuenta = p_nro_cuenta
            and c.nro_linea = p_nro_linea;
      EXCEPTION
        when verror then
          raise verror;
        when others then
          vmensaje := 'ERROR. Al actualizar cuenta de mesa de dinero ' || sqlerrm;
          raise verror;      
        end;               
     End if;   
       -- CRO-JM-07/2015: CROALCVC-1: Insertamos en el histórico de línea/producto:
       if  v_cod_modulo in ('4','5','6','8','10') and  
           nvl(pae_cnf.G_PROGRAMA, 'X') = ('GPPROFIN') then
           prp_ins_vin_productos(p_nro_linea,
                                 p_nro_cuenta);
       end if;
  End if;
exception
  when verror then
    RAISE_APPLICATION_ERROR( -20000, vmensaje );
  when others then
    RAISE_APPLICATION_ERROR( -20001, 'ERROR. En el proceso prp_des_lim_credito '||sqlerrm );
end;
/

