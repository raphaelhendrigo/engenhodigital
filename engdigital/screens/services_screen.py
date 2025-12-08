"""Services screen for Engenho Digital app."""

from kivy.properties import ListProperty, StringProperty
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.screenmanager import Screen


class ServicesScreen(Screen):
    """Simple list of offered services."""

    services = ListProperty(
        [
            {
                "title": "Desenvolvimento de Software",
                "description": "Aplicacoes web modernas em Flask, React, APIs e bancos relacionais/NoSQL.",
            },
            {
                "title": "Projetos Eletricos CAD/CAM",
                "description": "Diagramas, layouts, quadros e listas de materiais prontos para execucao.",
            },
            {
                "title": "Automacao e Dados",
                "description": "ETL/ELT, relatorios automatizados e pipelines para aliviar trabalho manual.",
            },
        ]
    )

    overview = ListProperty(
        [
            {
                "index": "1",
                "title": "Software sob medida",
                "description": "Sistemas web em Flask, React e cloud, focados em automacao, dashboards e integracoes.",
            },
            {
                "index": "2",
                "title": "Projetos eletricos em CAD/CAM",
                "description": "Plantas, diagramas, quadros e detalhamento tecnico para obras e industria.",
            },
            {
                "index": "3",
                "title": "Consultoria em dados e automacao",
                "description": "Dados para reduzir retrabalho, padronizar processos e ganhar previsibilidade.",
            },
        ]
    )

    detailed_services = ListProperty(
        [
            {
                "title": "Desenvolvimento de Software",
                "summary": "Aplicacoes web modernas usando Flask, React, APIs em Python e bancos relacionais e NoSQL.",
                "bullets": [
                    "Sistemas internos e portais web",
                    "Dashboards para indicadores de gestao",
                    "Integracao com servicos em nuvem e APIs",
                ],
            },
            {
                "title": "Projetos Eletricos CAD/CAM",
                "summary": "Projetos em AutoCAD e ferramentas CAM para instalacoes eletricas prediais e industriais.",
                "bullets": [
                    "Diagramas unifilares e trifilares",
                    "Layouts de iluminacao e tomadas",
                    "Quadros de cargas e listas de materiais",
                ],
            },
            {
                "title": "Automacao & Dados",
                "summary": "Modelagem de dados, automacao de relatorios e pipelines que aliviam trabalho manual.",
                "bullets": [
                    "Rotinas de ETL/ELT para planilhas e bancos",
                    "Automatizacao de relatorios tecnicos",
                    "Suporte a IA aplicada ao negocio",
                ],
            },
        ]
    )


class ServiceCard(BoxLayout):
    """Card-like container for displaying a service."""

    title = StringProperty("")
    description = StringProperty("")


class DetailedServiceCard(BoxLayout):
    """Card with summary and bullets."""

    title = StringProperty("")
    summary = StringProperty("")
    bullet1 = StringProperty("")
    bullet2 = StringProperty("")
    bullet3 = StringProperty("")
