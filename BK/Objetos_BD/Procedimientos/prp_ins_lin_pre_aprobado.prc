CREATE OR REPLACE PROCEDURE IT.PRP_INS_LIN_PRE_APROBADO
 IS
--- Líneas de Crédito cargadas en forma masiva
   CURSOR c_lineas IS
     SELECT DISTINCT t.cod_persona, t.cod_moneda, t.mto_limite, t.cod_campana, t.descripcion, t.fec_vencimiento, 
            t.fec_fin_campana, t.tip_garantia
       FROM pr_lin_pre_aprobados_tmp t
      WHERE NOT EXISTS (SELECT 0
                          FROM pr_lin_pre_aprobados p
                         WHERE t.cod_persona = p.cod_persona
                           AND t.cod_moneda = p.cod_moneda
                           AND t.mto_limite = p.mto_limite
                           AND t.fec_vencimiento = p.fec_vencimiento
                           AND t.tip_garantia = p.tip_garantia
                           AND t.cod_campana = p.cod_campana
                           AND t.fec_fin_campana = p.fec_fin_campana
                           AND t.cod_modulo = p.cod_modulo
                           AND (t.cod_modalidad IS NULL OR t.cod_modalidad = p.cod_modalidad)
                           AND t.mto_lim_modalidad = p.mto_lim_modalidad
                           AND NVL(p.estado, 'V') = 'V' );
     
   CURSOR c_lin_det(p_cod_persona VARCHAR2, p_cod_moneda VARCHAR2, p_cod_campana NUMBER, p_mto_limite NUMBER) IS    
     SELECT t.cod_modulo, t.cod_modalidad, t.mto_lim_modalidad
       FROM pr_lin_pre_aprobados_tmp t
      WHERE t.cod_persona = p_cod_persona
        AND t.cod_moneda  = p_cod_moneda
        AND t.cod_campana = p_cod_campana
        AND t.mto_limite  = p_mto_limite;
       
   CURSOR c_detalle IS    
     SELECT t.cod_persona, t.cod_moneda, t.mto_limite, t.cod_campana, t.cod_modulo, t.cod_modalidad, t.mto_lim_modalidad,
            t.fec_vencimiento, t.descripcion, t.tip_garantia, t.fec_fin_campana
       FROM pr_lin_pre_aprobados_tmp t;

   v_fechoy     date;
   v_existe     varchar2(1) := 'N';
   v_cantidad   number := 0;
   v_nro_linea  pr_lineas.nro_linea%TYPE;

BEGIN
   v_fechoy := pag_cal.fu_obt_fec_actual(1);
   FOR d IN c_detalle LOOP      
       IF d.cod_persona IS NULL THEN
          raise_application_error(-20009, 'El código de persona no puede ser nulo.');
       END IF;
       IF d.cod_moneda IS NULL THEN
          raise_application_error(-20009, 'El código de moneda no puede ser nulo.'||' Pers. :'||d.cod_persona);
       END IF;
       IF NVL(d.mto_limite, 0) <= 0 THEN
          raise_application_error(-20009, 'El monto de la línea pre-aprobada debe ser mayor a cero.'||' Pers. :'||d.cod_persona);
       END IF;
       IF d.cod_campana IS NULL THEN 
          raise_application_error(-20009, 'El código de la campaña no puede ser nulo.'||' Pers. :'||d.cod_persona);
       END IF;
       IF d.cod_modulo IS NULL THEN
          raise_application_error(-20009, 'El código del módulo no puede ser nulo.'||' Pers. :'||d.cod_persona);
       END IF;
       IF NVL(d.mto_lim_modalidad, 0) <= 0 OR d.mto_lim_modalidad > d.mto_limite THEN
          raise_application_error(-20009, 'El monto límite por modalidad debe ser mayor a cero y menor o igual al monto límite.'||' Pers. :'||d.cod_persona);   
       END IF;
       IF d.fec_vencimiento IS NULL OR d.fec_vencimiento <= v_fechoy THEN
          raise_application_error(-20009, 'La fecha de vencimiento no puede ser nula o menor o igual a la fecha de hoy.'||' Pers. :'||d.cod_persona);
       END IF;             
       IF d.descripcion IS NULL THEN
          raise_application_error(-20009, 'La descripción de la línea no puede ser nula.'||' Pers. :'||d.cod_persona);   
       END IF;
       IF d.fec_fin_campana IS NULL OR d.fec_fin_campana < v_fechoy THEN
          raise_application_error(-20009, 'La fecha fin de campaña no puede ser nula o menor a la fecha de hoy.'||' Pers. :'||d.cod_persona);   
       END IF;
       BEGIN
         SELECT COUNT(*)
           INTO v_cantidad
           FROM (SELECT DISTINCT t.cod_persona, t.cod_moneda, t.mto_limite, t.cod_campana, t.descripcion, t.fec_vencimiento, 
                        t.fec_fin_campana, t.tip_garantia
                   FROM pr_lin_pre_aprobados_tmp t
                  WHERE t.cod_persona      = d.cod_persona);
       EXCEPTION     
         WHEN OTHERS THEN
           v_cantidad := '0';
       END;            
       IF v_cantidad > 1 THEN
          raise_application_error(-20010, 'Los datos de persona, moneda, mto_límite, campaña, descripción, vencimiento,'||
          ' fec. otorgamiento, fin de campaña y garantía deben ser los mismos por Línea pre-aprobada.'||' Pers. :'||d.cod_persona);
       END IF;
       --Verifica que la persona exista
       BEGIN
         SELECT 'S'
           INTO v_existe
           FROM ba_personas
          WHERE cod_persona = d.cod_persona;
       EXCEPTION
         WHEN OTHERS THEN
           v_existe := 'N';
       END;
       IF v_existe = 'N' THEN
          raise_application_error(-20002, 'El código de persona ingresado no existe. Pers: '||d.cod_persona);
       END IF;   
       --Verifica que la campaña esté vigente
       BEGIN
         SELECT 'S'
           INTO v_existe
           FROM cr_campanas c
          WHERE c.cod_campana = d.cod_campana
            AND v_fechoy BETWEEN c.fec_inicio AND c.fec_vencimiento;
       EXCEPTION
         WHEN OTHERS THEN
           v_existe := 'N';
       END;
       IF v_existe = 'N' THEN
          raise_application_error(-20003, 'La campaña ingresada no existe o no está vigente. Pers: '||d.cod_persona||
                                          ' Mon: '||d.cod_moneda||' Camp: '||d.cod_campana);
       END IF;
       --Verifica que el módulo y modalidad estén habilitados para líneas de crédito
       IF NVL(fug_obt_pardinamico('LIM_PRO_HABILITADOS', d.cod_modulo, NVL(d.cod_modalidad, 51)), 'N') <> 'S' THEN
          raise_application_error(-20004, 'El módulo y la modalidad no existen o no están habilitados para ingreso de líneas de crédito. Pers: '||d.cod_persona);
       END IF;
       --Verifica que exista el tipo de garantía ingresado
       BEGIN
          SELECT 'S'
            INTO v_existe
            FROM pr_gar_tipos
           WHERE cod_garantia = d.tip_garantia
             AND NVL(activo, 'N') = 'S';
       EXCEPTION
         WHEN OTHERS THEN
           v_existe := 'N';      
       END; 
       IF v_existe = 'N' THEN
          raise_application_error(-20004, 'El tipo de garantía no existe o no está activo. Pers: '||d.cod_persona);
       END IF;   
   END LOOP;   
   
   FOR l IN c_lineas LOOP
       SELECT s_nro_linea.nextval 
         INTO v_nro_linea
         FROM DUAL;
       --Inserción de la Línea de Crédito
       BEGIN
         INSERT INTO pr_lineas( nro_linea,
                                cod_persona,
                                cod_moneda,
                                monto,
                                fec_vencimiento,
                                fec_otorgamiento,
                                mto_aplicado,
                                descripcion,
                                estado,
                                cotizacion,
                                cod_campana )
                        VALUES( v_nro_linea,
                                l.cod_persona,
                                l.cod_moneda,
                                l.mto_limite,
                                l.fec_vencimiento,
                                v_fechoy,
                                0,
                                l.descripcion,
                                'P',
                                pag_gen.fu_obt_cotizacion(pag_gen.FU_OBT_MON_FUERTE(),v_fechoy),
                                l.cod_campana );
       EXCEPTION
         WHEN OTHERS THEN
           raise_application_error(-20005, 'Error al insertar la línea de crédito. Pers: '||l.cod_persona||
                                           ' Mon: '||l.cod_moneda||' Camp: '||l.cod_campana||' - '||sqlerrm);
       END;
       --Inserción de Tipos de Garantía para Líneas
       BEGIN
         INSERT INTO pr_lin_tip_garantias( nro_linea,
                                           cod_garantia,
                                           mto_limite,
                                           mto_aplicado,
                                           rel_garantia )         
                                   VALUES( v_nro_linea,
                                           l.tip_garantia,
                                           l.mto_limite,
                                           0,
                                           1 ); 
       EXCEPTION 
         WHEN OTHERS THEN
           raise_application_error(-20006, 'Error al insertar el tipo de garantía de la línea de crédito. - '||sqlerrm);
       END;  
       FOR ld in c_lin_det(l.cod_persona, l.cod_moneda, l.cod_campana, l.mto_limite) LOOP
           --Inserción de Productos por Línea de Crédito
           BEGIN
             INSERT INTO pr_lin_tip_gar_mad( nro_linea,
                                             cod_garantia,
                                             cod_modulo,
                                             cod_modalidad,
                                             mto_limite,
                                             mto_aplicado )                                                         
                                     VALUES( v_nro_linea,
                                             l.tip_garantia,
                                             ld.cod_modulo,
                                             ld.cod_modalidad,
                                             ld.mto_lim_modalidad,
                                             0 );
           EXCEPTION
             WHEN OTHERS THEN
               raise_application_error(-20007, 'Error al insertar las modalidades por línea de crédito.  Pers: '||l.cod_persona||
                                               ' Mon: '||l.cod_moneda||' Camp: '||l.cod_campana||' Modal: '||ld.cod_modalidad||
                                               ' - '||sqlerrm);        
           END;                                                             
           --Inserción de Líneas Pre-Aprobadas
           BEGIN
             INSERT INTO pr_lin_pre_aprobados( nro_lin_pre_aprobado, 
                                               cod_persona, 
                                               cod_moneda, 
                                               mto_limite, 
                                               fec_vencimiento, 
                                               fec_otorgamiento, 
                                               descripcion, 
                                               tip_garantia, 
                                               cod_modulo, 
                                               cod_modalidad, 
                                               mto_lim_modalidad, 
                                               cod_campana, 
                                               fec_fin_campana, 
                                               estado )
                                       VALUES( v_nro_linea,
                                               l.cod_persona,
                                               l.cod_moneda,
                                               l.mto_limite,
                                               l.fec_vencimiento,
                                               v_fechoy,
                                               l.descripcion,
                                               l.tip_garantia,
                                               ld.cod_modulo,
                                               ld.cod_modalidad,
                                               ld.mto_lim_modalidad,
                                               l.cod_campana,
                                               l.fec_fin_campana,
                                               'V' );
           EXCEPTION
             WHEN OTHERS THEN
               raise_application_error(-20008, 'Error al insertar las líneas pre-aprobadas. - '||sqlerrm);
           END;            
       END LOOP;  
   END LOOP;
END;
/

