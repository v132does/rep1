CREATE OR REPLACE PROCEDURE IT.prc_gen_cta_corrientes(p_cod_persona ba_personas.cod_persona%TYPE,
                                                   p_cod_oficina ba_oficinas.cod_oficina%TYPE,
                                                   p_cod_moneda ba_monedas.cod_moneda%TYPE
                                                   DEFAULT pag_gen.fu_obt_mon_local,
                                                   p_nro_cta_origen VARCHAR2,
                                                   p_nro_cuenta OUT cc_cta_corrientes.nro_cuenta%TYPE ) IS
  v_cuenta       ge_cuentas.nro_cuenta%type;
  v_denominacion cc_cta_corrientes.denominacion%type;
  v_nom_chequera cc_cta_corrientes.nom_chequera%type;
  v_pri_nombre   ba_per_fisicas.pri_nombre%type;
  v_seg_nombre   ba_per_fisicas.seg_nombre%type;
  v_pri_apellido ba_per_fisicas.pri_apellido%type;
  v_seg_apellido ba_per_fisicas.seg_apellido%type;
  v_fec_actual   date default pag_cal.fu_obt_fec_actual(4);
  v_fec_apertura date;
  FUNCTION lf_obt_nombre
   (
      p_pri_nombre   VARCHAR2,
      p_seg_nombre   VARCHAR2,
      p_pri_apellido VARCHAR2,
      p_seg_apellido VARCHAR2,
      p_tamano       NUMBER
   ) RETURN VARCHAR2 IS
      v_nombre VARCHAR2(120);
   BEGIN

      IF length(p_pri_nombre||' '||p_seg_nombre||' '||p_pri_apellido||' '||p_seg_apellido) > p_tamano THEN
         IF length(p_pri_nombre||' '||p_pri_apellido||' '||p_seg_apellido) > p_tamano THEN
            IF length(p_pri_nombre||' '||p_pri_apellido||' '||p_seg_apellido) > p_tamano THEN
               v_nombre := p_pri_nombre||' '||p_pri_apellido;
            ELSE
               v_nombre := TRIM(p_pri_nombre||' '||p_pri_apellido||' '||p_seg_apellido);
            END IF;
         ELSE
            v_nombre := TRIM(p_pri_nombre||' '||p_pri_apellido||' '||p_seg_apellido);
         END IF;
      ELSE
         v_nombre := TRIM(p_pri_nombre||' '||p_seg_nombre||' '||p_pri_apellido||' '||p_seg_apellido);
      END IF;

      RETURN v_nombre;
   END;
BEGIN
  Begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 1; End; 
  BEGIN
    SELECT a.pri_nombre, a.seg_nombre,
           a.pri_apellido, a.seg_apellido
      INTO v_pri_nombre, v_seg_nombre,
           v_pri_apellido, v_seg_apellido
      FROM ba_per_fisicas a
     WHERE a.cod_persona = p_cod_persona;
  EXCEPTION
    WHEN no_data_found THEN
      raise_application_error(-20000,'Error en PRC_GEN_CTA_CORRIENTES Persona '||p_cod_persona||' Inexistente, o no es Persona Física.');
  END;
  v_denominacion := lf_obt_nombre(v_pri_nombre, v_seg_nombre,v_pri_apellido, v_seg_apellido,65);
  v_nom_chequera := lf_obt_nombre(v_pri_nombre, v_seg_nombre,v_pri_apellido, v_seg_apellido,60);
  v_cuenta := fug_obt_sig_nro_cuenta(4, 
                                     41, 
                                     p_cod_oficina,
                                     p_cod_moneda, 
                                     p_cod_persona);
  BEGIN
    select v_fec_actual-a.dia_atraso
      into v_fec_apertura
      from pr_cta_prestamos a
     where a.nro_cuenta = p_nro_cta_origen;
  EXCEPTION
    when others then
      raise_application_error(-20060, 'Error al buscar cuenta origen = '||p_nro_cta_origen||' '||SQLERRM);
  END;
  BEGIN
    INSERT INTO cc_cta_corrientes
        (cod_modulo, cod_modalidad, cod_oficina, nro_cuenta, dig_verificador,
         cod_moneda, denominacion, can_fir_requeridas, can_fir_registradas,
         fec_apertura, ret_personalizada, tas_personalizada, sal_minimo,
         aut_pendiente, acu_sobregiro, tra_prohibida, cta_combinada, estado,
         nom_chequera, mto_apertura, fre_extracto, cod_ente,
         reg_firma, cod_sub_modalidad)
    VALUES
        (4, 41, p_cod_oficina, v_cuenta, 0,
         p_cod_moneda, v_denominacion, 1, 1,
         v_fec_apertura, 'N', 'N', 0,
         'N', 'N', 'N', 'N', 'A',
         v_nom_chequera, 0, 'M', null,
         'INDIVIDUAL', 19);
  EXCEPTION
     WHEN OTHERS THEN
        raise_application_error(-20030, 'Error al insertar datos en CC_CTA_CORRIENTES. Persona = '||p_cod_persona||' '||SQLERRM);
  END;
  --
  BEGIN
    INSERT INTO ge_cta_clientes
         (cod_persona, nro_cuenta, dig_verificador, cod_oficina, cod_modulo,
          cod_modalidad, relacion)
    VALUES
         (p_cod_persona, v_cuenta, 0, p_cod_oficina, 4,
          41, 'P');

    EXCEPTION
      WHEN OTHERS THEN
        raise_application_error(-20050, 'Error al insertar datos en GE_CTA_CLIENTES. Persona: '
        ||p_cod_persona||' Cuenta: '||v_cuenta||SQLERRM);
    END;
   
   IF p_nro_cta_origen IS NOT NULL THEN 
     BEGIN
       INSERT INTO ge_cta_dat_adicionales
              (nro_cuenta, parametro, val_parametro)
        VALUES(v_cuenta, 'CTA_ORI_PRESTAMO', p_nro_cta_origen);
     END;
   END IF;
   p_nro_cuenta := v_cuenta;
   
END;
/

