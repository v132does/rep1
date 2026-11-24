CREATE OR REPLACE FUNCTION IT.fus_obt_are_bcp_cta(p_nro_cuenta IN ge_cuentas.nro_cuenta%TYPE,
                                                  p_cod_modulo IN ge_cuentas.cod_modulo%TYPE, -- JFF 25/11/2021
                                                  p_tip_saldo  IN cb_sal_inventarios_his.tip_saldo%TYPE default null,
                                                  p_cod_rubro  IN cb_sal_inventarios_his.cod_rubro%TYPE default null,
                                                  p_estado_his IN varchar2 default null

                                                  ) RETURN NUMBER IS 

  v_cod_area        sb_areas.cod_are_bcp%TYPE;
  v_plazo           NUMBER;
  r_pcpre           pr_cta_prestamos%ROWTYPE;
  r_pcmes           md_cta_documentos%ROWTYPE;
  v_tip_destino_esp ba_cod_referencias.val_minimo%type;
  v_dias_r          number(8); -- Días segun rubro JFF 03/12/2021
  v_cod_rubro       cb_rubros.cod_rubro%type;
BEGIN
  v_cod_rubro := p_cod_rubro;
  v_dias_r    := to_number(substr(p_cod_rubro, 3, 1));
  if p_cod_modulo = 6 then
    begin
      select cd.tip_des_especifico
        into v_tip_destino_esp
        from PR_CTA_DESTINOS cd
       where cd.nro_cuenta = p_nro_cuenta;
    exception
      when no_data_found then
        begin
          select a.val_minimo
            into v_tip_destino_esp
            from PR_CTA_PRESTAMOS   P,
                 PR_RUB_ECONOMICOS  R,
                 BA_COD_REFERENCIAS A
           WHERE R.COD_RUB_ECONOMICO = P.COD_RUB_ECONOMICO
             and a.val_minimo = p.tip_destino
             AND A.DOMINIO = 'TIP_DES_ESPECIFICO'
             and p.nro_cuenta = p_nro_cuenta;
        exception
          when others then
            v_tip_destino_esp := null;
        end;
      when others then
        v_tip_destino_esp := null;

    end;

    -- Obtiene rubro.
    if v_cod_rubro is null then
      select NVL(max(a.cod_rubro), '')
        into v_cod_rubro
        from cb_sal_inventarios a, cb_sal_inventarios_det b
       where a.nro_referencia = b.nro_referencia
         and b.nro_cuenta = p_nro_cuenta
         and a.tip_saldo = 'C';
    end if;
  else
    v_tip_destino_esp := null;
  end if;
  v_cod_area := NULL;
  pag_cta.pr_obt_cuenta(p_nro_cuenta);
  --determinar a que area pertenece la cuenta
  IF p_cod_modulo = 3 THEN
    --ahorros

    IF (instr(fug_obt_pardinamico('MAD_CAJ_AHORROS'),pag_cta.g_ctas.cod_modalidad ) > 0) and
       substr(v_cod_rubro, 1, 2) in ('21', '22') and
       substr(v_cod_rubro, 6, 3) in ('102', '138', '292') THEN
      --vista
      v_cod_area := 2021;
    ELSIF pag_cta.g_ctas.cod_modalidad = 32 THEN
      --a plazo
      v_cod_area := NULL;
    ELSIF pag_cta.g_ctas.cod_modalidad = 33 and
          substr(v_cod_rubro, 1, 2) in ('21', '22') THEN
      v_plazo := pag_cta.g_ctas.fec_vencimiento -
                 pag_cta.g_ctas.fec_apertura;
      if substr(v_cod_rubro, 6, 3) in ('104', '152') then
        IF v_plazo <= 90 and (v_dias_r >= 2 and v_dias_r < 6) THEN
          -- JFF 26/11/2021
          v_cod_area := '2034';
        ELSIF v_plazo <= 180 and v_dias_r = 5 THEN
          v_cod_area := '2035';
        ELSIF v_plazo <= 365 and v_dias_r = 6 THEN
          v_cod_area := '2036';
        ELSIF v_plazo > 365 and substr(v_cod_rubro, 3, 1) in ('7', '8') THEN
          v_cod_area := '2037';
        END IF;
      END iF;
      if substr(v_cod_rubro, 6, 3) in ('156', '298', '306') then
        IF v_plazo <= 180 and v_dias_r between 2 and 5 THEN
          v_cod_area := '2075';
        ELSIF v_plazo <= 365 and v_dias_r = 6 THEN
          v_cod_area := '2076';
        ELSIF v_plazo > 365 and v_dias_r between 7 and 8 THEN
          v_cod_area := '2077';
        END IF;
      end if;
      IF substr(v_cod_rubro, 6, 3) in ('142', '146') and
         pag_cta.g_ctas.cod_modalidad in (31, 33, 38, 39, 334) and
         v_dias_r between 1 and 6 THEN
        v_cod_area := '2140';
      END IF;
    END IF;
  ELSIF p_cod_modulo = 4 THEN
    v_cod_area := 1080;

    --sobregiro
  ELSIF p_cod_modulo = 6 THEN
    pap_pre.pr_obt_dat_prestamo(p_nro_cuenta, r_pcpre);
    v_plazo := r_pcpre.fec_vencimiento - r_pcpre.fec_inicio;
    --  IF fug_obt_tip_implementacion = 3  THEN -- JFF no pasa por aqui es 9
    --     IF v_plazo <= 365 THEN
    --        v_cod_area := 1016;
    --     ELSE
    --        v_cod_area := 1017;
    --     END IF;
    --  ELSE
    IF r_pcpre.cod_modalidad IN (670, 671) OR
       nvl(fup_obt_tip_bono(r_pcpre.cod_modalidad), 'N') = 'S' OR
       nvl(fup_obt_tip_letra(r_pcpre.cod_modalidad), 'N') = 'S' THEN
      IF r_pcpre.cod_modalidad IN (670, 671) AND v_plazo <= 365 THEN
        v_cod_area := 1096;
      ELSIF r_pcpre.cod_modalidad IN (670, 671) THEN
        v_cod_area := 1097;
      END IF;
      IF r_pcpre.cod_modalidad = 656 AND v_plazo <= 365 THEN
        v_cod_area := 1126;
      ELSIF r_pcpre.cod_modalidad = 656 THEN
        v_cod_area := 1127;
      END IF;
    ELSE
      --  IF nvl(r_pcpre.cod_banca, 1) = 4 OR nvl(fup_obt_tip_descuento(r_pcpre.cod_modalidad),'x') in ('C','D') then
      IF v_tip_destino_esp in (1, 2, 5) and
         substr(v_cod_rubro, 1, 2) = '14' and
         substr(v_cod_rubro, 6, 3) in
         ('169', '173', '351', '405', '443', '449')
      --and   r_pcpre.cod_modalidad not in (60,65,627)
       THEN
        -- BANCA CORPORATIVA
        IF v_plazo <= 365 and v_dias_r between 2 and 6 THEN
          v_cod_area := 1016;
        ELSif substr(v_cod_rubro, 3, 1) in ('7', '8') THEN
          v_cod_area := 1017;
        END IF;
      END IF;
      -- ELSE
      IF v_tip_destino_esp = 4 THEN
        if substr(v_cod_rubro, 6, 3) in ('169', '173', '443', '449') and
           upper(r_pcpre.descripcion) not like ('%CONSUMO%') then
          -- vivienda
          IF v_plazo <= 365 and v_dias_r between 2 and 6 THEN
            v_cod_area := 1036;
          ELSif substr(v_cod_rubro, 3, 1) in ('7', '8') then
            v_cod_area := 1037;
          END IF;
        end if;
      end if;
      IF v_tip_destino_esp = 3 THEN
        -- consumo
        --IF p_tip_saldo='C' and p_estado_his ='VIGENTE'
        if substr(v_cod_rubro, 1, 2) = '14' and substr(v_cod_rubro, 6, 3) in ('169', '173', '443', '449', '302') THEN
          IF v_plazo <= 365 and substr(v_cod_rubro, 3, 1) in ('6') THEN
            v_cod_area := 1026; -- JFF --1016; --1026;
          ELSif substr(v_cod_rubro, 3, 1) in ('7', '8') then
            v_cod_area := 1027;
          END IF;
        END IF;
      end if;

      if substr(v_cod_rubro, 1, 2) = '14' and
         substr(v_cod_rubro, 6, 3) in ('209') then
        if r_pcpre.cod_modalidad IN (628, 629, 630, 615, 618, 617, 209,668,982) then
          -- Vivienda AFD
          IF v_plazo <= 365 and v_dias_r between 1 and 6 THEN
            v_cod_area := 1146;
          ELSif v_dias_r between 7 and 8 then
            v_cod_area := 1147;
          END IF;
        elsif r_pcpre.cod_modalidad IN (631) then
          -- AFD Otros
          IF v_plazo <= 365 and v_dias_r between 1 and 6 THEN
            v_cod_area := 1156;
          ELSIF v_dias_r between 7 and 8 then
            v_cod_area := 1157;
          END IF;

        end if;
      end if;
      --END IF;
      IF fug_obt_pardinamico('SIB_MAD_COM_CARTERA',
                             r_pcpre.cod_modulo,
                             r_pcpre.cod_modalidad) = 'S' THEN
        --Compras cartera
        if substr(v_cod_rubro, 6, 3) in ('433') then
          IF v_plazo <= 365 and v_dias_r between 2 and 6 THEN
            v_cod_area := 1176;
          ELSif v_dias_r between 7 and 8 then
            v_cod_area := 1177;
          END IF;
        end if;
      END IF;
    END IF;
    --END IF;
    -- Préstamo Personal -- JFF 25/11/2021
    IF v_tip_destino_esp = 3 and p_tip_saldo = 'C' and
       p_estado_his = 'VIGENTE' --r_pcpre.estado='C'
       and substr(v_cod_rubro, 6, 3) in ('169', '173', '443', '449') THEN
      IF v_plazo <= 90 and v_dias_r between 2 and 4 THEN
        v_cod_area := 1166;
      ELSIF v_plazo > 90 and v_plazo <= 180 and
            substr(v_cod_rubro, 3, 1) in ('5') then
        v_cod_area := 1167;
      END IF;
    END IF;
    if substr(v_cod_rubro, 6, 3) in ('100') and
       substr(v_cod_rubro, 9, 2) not in ('02') and v_dias_r between 1 and 8 then
      -- JFF 25/11/2021
      v_cod_area := 2170;
    end if;

    --COLOCACIONES PLAZA LOCAL
    IF substr(v_cod_rubro, 1, 2) = '13' and
       substr(v_cod_rubro, 6, 3) in ('131') THEN
      IF v_plazo <= 365 and v_dias_r between 1 and 6 THEN
        v_cod_area := 1126;
      ELSIF v_dias_r between 7 and 8 THEN
        v_cod_area := 1127;
      END IF;
    END IF;

  ELSIF p_cod_modulo = 5 THEN
    if substr(v_cod_rubro, 6, 3) in ('205') then
      v_cod_area := 1066;
    end if;
  ELSIF p_cod_modulo = 10 THEN
    ---Mesa de Dinero
    pam_doc.pr_obt_datos(p_nro_cuenta, r_pcmes);
    v_plazo := r_pcmes.fec_vencimiento - r_pcmes.fec_inicio;
    --TITULOS DE VALORES
    --IF r_pcmes.cod_modalidad = 100 THEN
    --   IF v_plazo <= 365 THEN
    --      v_cod_area := 1106;
    --   ELSE
    --      v_cod_area := 1107;
    --   END IF;
    -- END IF;

    --BONOS DEL TESORO
    IF substr(v_cod_rubro, 1, 2) = '12' and r_pcmes.cod_modalidad = 123 and
       substr(v_cod_rubro, 6, 3) in ('123') THEN
      -- JFF 25/11/2021
      --105 THEN
      IF v_plazo <= 365 and v_dias_r between 1 and 6 and
         substr(v_cod_rubro, 6, 3) in ('123') THEN
        v_cod_area := 1106;
      ELSif v_dias_r between 7 and 8 then
        v_cod_area := 1107;
      END IF;
    END IF;

    --PRESTAMOS RECIBIDOS DE BCOS LOCALES
    IF substr(v_cod_rubro, 1, 2) = '21' and
       substr(v_cod_rubro, 6, 3) in ('390') THEN
      -- JFF25/11/2021
      v_cod_area := 2150;
    END IF;

    --COLOCACIONES PLAZA LOCAL
    IF substr(v_cod_rubro, 1, 2) = '13' and
       substr(v_cod_rubro, 6, 3) in ('131') THEN
      IF v_plazo <= 365 and v_dias_r between 1 and 6 THEN
        v_cod_area := 1126;
      ELSIF v_dias_r between 7 and 8 THEN
        v_cod_area := 1127;
      END IF;
    END IF;

    --PRESTAMOS RECIBIDOS AFD
    --   IF substr(v_cod_rubro,1,2)='21'
    --   and substr(v_cod_rubro,6,3) in ('390')
    --  THEN
    --   v_cod_area := 2150;
    --- END IF;

    --PRTMOS REC DEL EXT- OTROS BANCOS
    IF substr(v_cod_rubro, 6, 3) in ('114', '116') THEN
      v_cod_area := 2180;
    END IF;

    --BONOS PRIVADOS  - MERCADO PRIMARIO
    IF r_pcmes.cod_modalidad = 124 THEN
      IF v_plazo <= 90 THEN
        v_cod_area := 2104;
      ELSIF v_plazo <= 180 THEN
        v_cod_area := 2105;
      ELSIF v_plazo <= 365 THEN
        v_cod_area := 2106;
      ELSIF v_plazo > 365 THEN
        v_cod_area := 2107;
      END IF;
    END IF;

  END IF;
  --
  if substr(v_cod_rubro, 6, 3) in ('100') -- rubro
     and substr(v_cod_rubro, 9, 2) in ('02') -- sub cuenta
   then
    v_cod_area := 2160;
  end if;

  RETURN v_cod_area;
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20100,
                            'Obt.area cta ' || p_nro_cuenta || '-' ||
                            SQLERRM);
END;
/
